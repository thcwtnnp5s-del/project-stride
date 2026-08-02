## 0.1.0

* Device-bound reconciliation identity in the iOS Keychain
  (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), plus
  `NSURLIsExcludedFromBackupKey` applied to the save directory and every file
  `StorageLayout` declares, re-applied on every launch.
