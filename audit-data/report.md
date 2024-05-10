---
title: PasswordStore Audit Report
author: Antonio María Rodríguez-Ynyesto Sánchez
date: 11th of February, 2024
header-includes:
  - \usepackage{titling}
  - \usepackage{graphicx}
---

\begin{titlepage}
    \centering
    \begin{figure}[h]
        \centering
        \includegraphics[width=0.5\textwidth]{logo.pdf} 
    \end{figure}
    \vspace*{2cm}
    {\Huge\bfseries PasswordStore Audit Report\par}
    \vspace{1cm}
    {\Large Version 1.0\par}
    \vspace{2cm}
    {\Large\itshape Cyfrin.io\par}
    \vfill
    {\large \today\par}
\end{titlepage}

\maketitle

<!-- Your report starts here! -->

Prepared by: [Antonio María Rodríguez-Ynyesto Sánchez](https://www.linkedin.com/in/antonio-maria-rodriguez-ynyesto-sanchez/)

Lead security researcher: Antonio María Rodríguez-Ynyesto Sánchez

# Table of Contents
- [Table of Contents](#table-of-contents)
- [Protocol Summary](#protocol-summary)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
  - [Roles](#roles)
- [Executive Summary](#executive-summary)
  - [Issues found](#issues-found)
- [Findings](#findings)
  - [High](#high)
    - [\[H-1\] Storing the password on-chain makes it visible to anyone, and not at all private](#h-1-storing-the-password-on-chain-makes-it-visible-to-anyone-and-not-at-all-private)
    - [\[H-2\] `PasswordStore::setPassword` has no access controls, so a non-owner could change the password](#h-2-passwordstoresetpassword-has-no-access-controls-so-a-non-owner-could-change-the-password)
  - [Informational](#informational)
    - [\[I-1\] The `PasswordStore::getPassword` natspec indicates a parameter that doesn't exist, causing the natspec to be incorrect](#i-1-the-passwordstoregetpassword-natspec-indicates-a-parameter-that-doesnt-exist-causing-the-natspec-to-be-incorrect)

# Protocol Summary

PasswordStore is a protocol dedicated to storage and retrieval of a user's passwords. The protocol is designed to be used by a single user, and is not designed to be used by multiple users. Only the owner should be able to set and access this password.

# Disclaimer

The auditing team makes all effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the findings provided in this document. A security audit by the team is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the Solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

We use the [CodeHawks](https://docs.codehawks.com/hawks-auditors/how-to-evaluate-a-finding-severity) severity matrix to determine severity. See the documentation for more details.

# Audit Details 

Commit hash:
```
7d55682ddc4301a7b13ae9413095feffd9924566
```

## Scope 

```
./src/
#-- PasswordStore.sol
```

## Roles

- Onwer: The user who can set the password and read the password.
- Outsiders no one else should be able to set and read the password.
  
# Executive Summary

* Add some notes about how the audit went, types of things you found, etc.*
* We spent X hours with Z editors using Y tools, etc.*
* 
## Issues found

| Severity | Number of issues found |
| -------- | ---------------------- |
| High     | 2                      |
| Medium   | 0                      |
| Low      | 0                      |
| Info     | 1                      |
| Total    | 3                      |

# Findings
## High

### [H-1] Storing the password on-chain makes it visible to anyone, and not at all private

**Description:** All data stored on-chain is visible to anyone and can be read directly from the blockchain. The `PasswordStore::s_password` variable is intended to be a private variable and only accessed through the `PasswordStore::getPassword` function, which is intended to be only called by the owner of the contract.

We show one method of reading any data off chain below.

**Impact:** Anyone can read the private password, severely breaking the functionality of the protocol.

**Proof of Concept:** (Proof of code)

The below test case shows how anyone can read the password directly from the blockchain.

1. Create a locally running chain
```bash
anvil
```

2. Deploy the contract to the chain
```
make deploy
```

3. Run the storage tool
```
cast storage <ADDRESS_HERE> 1 --rpc-url http://127.0.0.1:85
```

You'll get an output that looks like this:
`0x6d7950617373776f726400000000000000000000000000000000000000000014`

4. Parse the output
You can then parse the hex to a string with 
```
cast parse-bytes32-string 0x6d7950617373776f726400000000000000000000000000000000000000000014
```

And get the password that was stored in the `s_password` variable:
```
myPassword
```

**Recommended Mitigation:**  Due to this, the overall architecture of the contract should be rethought. One could encrypt the password off-chain, and then store the encrypted password on-chain. This would require the user to remember another password off-chain to decrypt the password. However, you'd also likely want to remove the view function as you wouldn't want the user to accidentally send a transaction with the password that decrypts your password.

### [H-2] `PasswordStore::setPassword` has no access controls, so a non-owner could change the password

**Description:** The `PasswordStore::setPassword` functino is set to be an `external`function, however, the natspec of the function and overall purpose of the smart contract is that `This function allows only the owner to set a new password.`.

```javascript
    function setPassword(string memory newPassword) external {
@>      // @audit any user can set a password!! - missing access control
        s_password = newPassword;
        emit SetNetPassword();
    }
```

**Impact:** Anyone can set/change the password of the contarct, severly breaking the contract intended functionality.

**Proof of Concept:** Add the following to the `PasswordStore.t.sol` test file:

<details>
<summary>Test code</summary>

```javascript
    function test_anyone_can_set_password(address randomAddress) public {
        vm.assume(randomAddress != owner);
        vm.prank(randomAddress);
        string memory expectedPassword = "myNewPassword";
        passwordStore.setPassword(expectedPassword);

        vm.prank(owner);
        string memory actualPassword = passwordStore.getPassword();
        assertEq(actualPassword, expectedPassword);
    }
```

</details>

**Recommended Mitigation:** Add an access control conditional to the `PasswordStore::setPassword` function:

```javascript
if(msg.sender != s_owner){
    revert PassworStore__NotOwner();
}
```

## Informational

### [I-1] The `PasswordStore::getPassword` natspec indicates a parameter that doesn't exist, causing the natspec to be incorrect


**Description:** The `PasswordStore::getPassword` function signature is `getPassword()` while the natspec says it should be `getPassword(string)`.

```javascript
    /*
     * @notice This allows only the owner to retrieve the password.
     * @param newPassword The new password to set.
     */
```

**Impact:** The natspec is incorrect.

**Recommended Mitigation:** Remove the incorrect natspec line.

```diff
-  * @param newPassword The new password to set.
```