// Place at: lib/theme/models/comic.dart

class Comic {
  final int? id;
  final String comicVineId;
  final String? volumeId;        // Comic Vine volume (series) ID — used for run lookup
  final String title;
  final String seriesName;
  final String? issueNumber;
  final int? publicationYear;
  final String? publisher;
  final String? description;
  final String? coverImageUrl;
  final String? writers;
  final String? artists;
  final String? barcode;
  final bool isRead;
  final int starRating;          // 0–5
  final bool isWishlisted;
  final DateTime addedDate;

  Comic({
    this.id,
    required this.comicVineId,
    this.volumeId,
    required this.title,
    required this.seriesName,
    this.issueNumber,
    this.publicationYear,
    this.publisher,
    this.description,
    this.coverImageUrl,
    this.writers,
    this.artists,
    this.barcode,
    this.isRead = false,
    this.starRating = 0,
    this.isWishlisted = false,
    DateTime? addedDate,
  }) : addedDate = addedDate ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'comicVineId': comicVineId,
        'volumeId': volumeId,
        'title': title,
        'seriesName': seriesName,
        'issueNumber': issueNumber,
        'publicationYear': publicationYear,
        'publisher': publisher,
        'description': description,
        'coverImageUrl': coverImageUrl,
        'writers': writers,
        'artists': artists,
        'barcode': barcode,
        'isRead': isRead ? 1 : 0,
        'starRating': starRating,
        'isWishlisted': isWishlisted ? 1 : 0,
        'addedDate': addedDate.toIso8601String(),
      };

  factory Comic.fromMap(Map<String, dynamic> map) => Comic(
        id: map['id'] as int?,
        comicVineId: map['comicVineId'] as String,
        volumeId: map['volumeId'] as String?,
        title: map['title'] as String,
        seriesName: map['seriesName'] as String,
        issueNumber: map['issueNumber'] as String?,
        publicationYear: map['publicationYear'] as int?,
        publisher: map['publisher'] as String?,
        description: map['description'] as String?,
        coverImageUrl: map['coverImageUrl'] as String?,
        writers: map['writers'] as String?,
        artists: map['artists'] as String?,
        barcode: map['barcode'] as String?,
        isRead: (map['isRead'] as int? ?? 0) == 1,
        starRating: map['starRating'] as int? ?? 0,
        isWishlisted: (map['isWishlisted'] as int? ?? 0) == 1,
        addedDate: DateTime.parse(map['addedDate'] as String),
      );

  Comic copyWith({
    int? id,
    String? comicVineId,
    String? volumeId,
    String? title,
    String? seriesName,
    String? issueNumber,
    int? publicationYear,
    String? publisher,
    String? description,
    String? coverImageUrl,
    String? writers,
    String? artists,
    String? barcode,
    bool? isRead,
    int? starRating,
    bool? isWishlisted,
    DateTime? addedDate,
  }) =>
      Comic(
        id: id ?? this.id,
        comicVineId: comicVineId ?? this.comicVineId,
        volumeId: volumeId ?? this.volumeId,
        title: title ?? this.title,
        seriesName: seriesName ?? this.seriesName,
        issueNumber: issueNumber ?? this.issueNumber,
        publicationYear: publicationYear ?? this.publicationYear,
        publisher: publisher ?? this.publisher,
        description: description ?? this.description,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        writers: writers ?? this.writers,
        artists: artists ?? this.artists,
        barcode: barcode ?? this.barcode,
        isRead: isRead ?? this.isRead,
        starRating: starRating ?? this.starRating,
        isWishlisted: isWishlisted ?? this.isWishlisted,
        addedDate: addedDate ?? this.addedDate,
      );
}