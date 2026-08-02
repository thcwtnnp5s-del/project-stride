import 'package:meta/meta.dart';

/// The namespaces a content ID may declare.
///
/// A closed set on purpose. An open namespace would let a typo in a reference
/// look like a new kind of thing rather than a mistake.
enum ContentNamespace {
  item,
  skill,
  location,
  resourceNode('resource_node'),
  recipe,
  enemy,
  profile;

  const ContentNamespace([String? wireName]) : _wireName = wireName;

  final String? _wireName;

  /// The form written in JSON.
  String get wire => _wireName ?? name;

  static ContentNamespace? fromWire(String value) {
    for (final ContentNamespace ns in ContentNamespace.values) {
      if (ns.wire == value) return ns;
    }
    return null;
  }

  static String get allWire =>
      ContentNamespace.values.map((ContentNamespace n) => n.wire).join(', ');
}

/// A stable, namespaced machine identifier — `item.training_sword`.
///
/// ## Why this is a type and not a String
///
/// IDs are the one thing in the content model that must never change after
/// release: they appear in saves, in cross-references, and eventually in
/// anything a server might store. Giving them a type means a location ID cannot
/// be silently passed where an item ID belongs, and means the syntax rules are
/// enforced in one place rather than at every call site.
///
/// ## Rules
///
/// * lowercase only
/// * exactly one dot, separating a known namespace from a slug
/// * slug is `[a-z0-9_]`, starting with a letter, no doubled or trailing `_`
/// * globally unique across the whole bundle, not merely within a file
/// * **independent of display names.** Display names are a separate field, may
///   be changed freely, and must never be used as a reference key.
@immutable
final class ContentId implements Comparable<ContentId> {
  const ContentId._(this.namespace, this.slug);

  final ContentNamespace namespace;
  final String slug;

  /// The canonical wire form, `namespace.slug`.
  String get value => '${namespace.wire}.$slug';

  static final RegExp _slugPattern = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');

  /// Parses [raw], returning null with a reason when it is not a valid ID.
  ///
  /// Returns a reason rather than throwing so the validator can collect every
  /// malformed ID in one pass instead of stopping at the first.
  static ContentIdParse parse(String raw) {
    if (raw.isEmpty) {
      return const ContentIdParse._failure(
        'the identifier is empty',
        'give it a value of the form `namespace.slug`, e.g. `item.oak_log`',
      );
    }
    if (raw != raw.toLowerCase()) {
      return ContentIdParse._failure(
        'identifiers must be lowercase, found "$raw"',
        'write it as "${raw.toLowerCase()}"',
      );
    }
    if (raw.contains(' ')) {
      return const ContentIdParse._failure(
        'identifiers must not contain spaces',
        'use underscores between words, e.g. `item.training_sword`',
      );
    }

    final int dot = raw.indexOf('.');
    if (dot == -1) {
      return ContentIdParse._failure(
        'identifiers must be namespaced, found "$raw"',
        'prefix it with a namespace, e.g. `item.$raw`. '
            'Valid namespaces: ${ContentNamespace.allWire}',
      );
    }
    if (raw.indexOf('.', dot + 1) != -1) {
      return const ContentIdParse._failure(
        'identifiers must contain exactly one dot',
        'use a single namespace separator, e.g. `location.havens_rest`',
      );
    }

    final String namespacePart = raw.substring(0, dot);
    final String slugPart = raw.substring(dot + 1);

    final ContentNamespace? namespace = ContentNamespace.fromWire(
      namespacePart,
    );
    if (namespace == null) {
      return ContentIdParse._failure(
        'unknown namespace "$namespacePart"',
        'use one of: ${ContentNamespace.allWire}',
      );
    }
    if (!_slugPattern.hasMatch(slugPart)) {
      return ContentIdParse._failure(
        'invalid slug "$slugPart"',
        'use lowercase letters, digits, and single underscores, starting with '
            'a letter, e.g. `${namespace.wire}.bronze_sword`',
      );
    }

    return ContentIdParse._success(ContentId._(namespace, slugPart));
  }

  /// Parses a known-good ID. For test fixtures and constants only — content
  /// loaded from files always goes through [parse] so errors are collected.
  static ContentId unchecked(String raw) {
    final ContentIdParse result = parse(raw);
    final ContentId? id = result.id;
    if (id == null) {
      throw ArgumentError.value(raw, 'raw', result.explanation);
    }
    return id;
  }

  @override
  int compareTo(ContentId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is ContentId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// The outcome of parsing an identifier: either an ID, or a reason and a fix.
@immutable
final class ContentIdParse {
  const ContentIdParse._success(this.id) : explanation = '', suggestion = '';

  const ContentIdParse._failure(this.explanation, this.suggestion) : id = null;

  final ContentId? id;
  final String explanation;
  final String suggestion;

  bool get isValid => id != null;
}
