/// The file formats the exporter can write.
enum ExportFormat { jpeg, png }

extension ExportFormatLabel on ExportFormat {
  String get extension => this == ExportFormat.jpeg ? 'jpg' : 'png';
  String get mime => this == ExportFormat.jpeg ? 'image/jpeg' : 'image/png';
  String get label => this == ExportFormat.jpeg ? 'JPEG' : 'PNG';
}
