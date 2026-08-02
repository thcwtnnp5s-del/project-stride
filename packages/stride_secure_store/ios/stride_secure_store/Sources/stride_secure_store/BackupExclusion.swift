import Foundation

/// `NSURLIsExcludedFromBackupKey`, applied to the save directory and to every
/// file `StorageLayout` declares.
///
/// ===========================================================================
/// Why this runs on every launch AND after every write
/// ===========================================================================
///
/// The exclusion is a resource value on the *filesystem node*, not a property
/// of the app or of a path. It disappears whenever the node does:
///
///   * a restore or a reinstall recreates `project_stride/`,
///   * a wipe-and-recover recreates it through `StorageLayout.ensureExists`,
///   * a file the layout merely *may* create — the journal sidecar — appears
///     for the first time hours after launch.
///
/// A one-shot "set it at install time" would be correct for exactly as long as
/// nobody deleted a directory, and would then be silently wrong forever, with
/// nothing anywhere reporting it. So this is idempotent, cheap, and runs at
/// every startup.
///
/// **A launch sweep alone is still not enough**, and this is the part F-06
/// originally got wrong. Apple documents resource values as living on the node,
/// and the ordinary file operations a save system performs replace the node
/// underneath a stable path:
///
///   * `FileLedgerJournal.replaceLines` writes a sidecar and renames it over
///     the journal. After a compaction the journal path names the *sidecar's*
///     node, which was never excluded.
///   * `Data.write(options: .atomic)` and `FileManager.replaceItemAt` do the
///     same thing by construction.
///   * Any file created after the sweep — a snapshot slot on the first commit,
///     the transaction lock, the sidecar during a compaction — is born without
///     the attribute.
///
/// `testTheAttributeIsLostWhenTheNodeIsReplaced` demonstrates each of those on
/// a real APFS volume in the simulator. So `apply(paths:)` exists as the cheap
/// per-write call, and `BACKUP_EXCLUSION_CONTRACT.md` names the exact call
/// sites that must use it.
///
/// Excluding the *directory* is not sufficient on its own either. The attribute
/// is not documented as inherited by files created inside an excluded
/// directory, so each declared file is excluded in its own right. Both, always.
///
/// ===========================================================================
/// Defence in depth, and which control does what
/// ===========================================================================
///
/// The Keychain identity is the control that *restores the refusal*: it does
/// not travel, so a restored device finds a save with no identity and blocks.
///
/// This is the control that stops the ledger travelling in the first place. It
/// is weaker — a user can restore a device, and Apple can change backup
/// behaviour — which is exactly why it is the second layer and not the first.
///
/// ===========================================================================
/// What this cannot prove
/// ===========================================================================
///
/// Setting the attribute and reading it back proves the attribute is set. It
/// does not prove Apple's backup machinery honours it, which needs a real
/// iCloud backup and a real restore onto a second physical device.
enum BackupExclusion {

  struct Report {
    var excluded: [String] = []
    var missing: [String] = []
    /// `path\treason`.
    var failed: [String] = []
  }

  /// Applies the exclusion to [directoryPath] and each of [filePaths], and
  /// verifies each one by reading the attribute back.
  ///
  /// Read-back rather than "the setter did not throw", for the same reason
  /// `writeVerified` reads its bytes back: a call that returns successfully and
  /// leaves the attribute unset is the failure this exists to catch, and it is
  /// invisible from the setter's return.
  static func apply(directoryPath: String, filePaths: [String]) -> Report {
    // The directory first. If it does not exist, every file under it is
    // missing too, and reporting five separate missings for one cause reads as
    // five problems.
    apply(paths: [directoryPath] + filePaths)
  }

  /// The same work over a bare list, with no directory and no launch-sweep
  /// framing.
  ///
  /// This is the per-write entry point. It is deliberately the *same* code as
  /// the launch sweep rather than a second, cheaper implementation: a
  /// re-application that skipped the read-back "because it is on the hot path"
  /// would report success for exactly the case — a node replaced underneath a
  /// stable path — that it exists to catch.
  static func apply(paths: [String]) -> Report {
    var report = Report()

    for path in paths {
      switch exclude(path: path) {
      case .excluded:
        report.excluded.append(path)
      case .missing:
        report.missing.append(path)
      case .failed(let reason):
        report.failed.append("\(path)\t\(reason)")
      }
    }

    return report
  }

  enum Outcome {
    case excluded
    case missing
    case failed(String)
  }

  static func exclude(path: String) -> Outcome {
    guard FileManager.default.fileExists(atPath: path) else {
      // Not a failure. `StorageLayout.allFiles` names every file the layout
      // *may* create; the journal sidecar exists only during a compaction.
      return .missing
    }

    var url = URL(fileURLWithPath: path)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true

    do {
      try url.setResourceValues(values)
    } catch {
      return .failed("\(error)")
    }

    // A *fresh* URL. `URL` caches resource values, so re-reading the same
    // instance would return the value we just wrote into the cache and would
    // pass whether or not the filesystem accepted it.
    let verification = URL(fileURLWithPath: path)
    do {
      let read = try verification.resourceValues(forKeys: [
        .isExcludedFromBackupKey
      ])
      guard read.isExcludedFromBackup == true else {
        return .failed("attribute did not stick")
      }
      return .excluded
    } catch {
      return .failed("read-back: \(error)")
    }
  }

  /// Reads the current state without changing anything. Diagnostics and tests.
  static func inspect(paths: [String]) -> (
    excluded: [String], notExcluded: [String], missing: [String]
  ) {
    var excluded: [String] = []
    var notExcluded: [String] = []
    var missing: [String] = []

    for path in paths {
      guard FileManager.default.fileExists(atPath: path) else {
        missing.append(path)
        continue
      }
      let url = URL(fileURLWithPath: path)
      let value = try? url.resourceValues(forKeys: [.isExcludedFromBackupKey])
      if value?.isExcludedFromBackup == true {
        excluded.append(path)
      } else {
        notExcluded.append(path)
      }
    }

    return (excluded, notExcluded, missing)
  }
}
