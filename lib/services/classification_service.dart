import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:csv/csv.dart';
import 'package:skripsi/models/disease_model.dart';
import 'package:skripsi/models/feature_model.dart';
import 'package:color/color.dart';

class DistanceCalculator {
  static double euclideanDistance(FeatureModel model1, FeatureModel model2) {
    double distance = sqrt(
      pow(model1.meanH - model2.meanH, 2) +
          pow(model1.meanS - model2.meanS, 2) +
          pow(model1.meanV - model2.meanV, 2) +
          pow(model1.eccentricity - model2.eccentricity, 2),
    );

    return distance;
  }
}

class ClassificationService {
  Future<FeatureModel> extractFeatures(String imagePath) async {
    // Memuat gambar dari jalur berkas
    final File imageFile = File(imagePath);
    final List<int> imageBytes = await imageFile.readAsBytes();
    final img.Image? image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Kesalahan saat memuat gambar.');
    }

    // Mengambil fitur warna HSV
    double sumH = 0.0;
    double sumS = 0.0;
    double sumV = 0.0;
    int pixelCount = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        // Mengambil komponen merah, hijau, dan biru dari nilai piksel
        int red = img.getRed(pixel);
        int green = img.getGreen(pixel);
        int blue = img.getBlue(pixel);

        final color = RgbColor(
            red, green, blue); // Gunakan pustaka 'color' untuk konversi RGB ke HSV
        final hsv = color.toHsvColor();
        sumH += hsv.h;
        sumS += hsv.s;
        sumV += hsv.v;
        pixelCount++;
      }
    }

    if (pixelCount == 0) {
      throw Exception('Tidak ada piksel ditemukan dalam gambar.');
    }

    double meanH = sumH / pixelCount;
    double meanS = sumS / pixelCount;
    double meanV = sumV / pixelCount;

    // Mengambil fitur eksentrisitas (asumsikan gambar adalah grayscale)
    double eccentricity = calculateEccentricity(image);

    // Membuat objek FeatureModel dengan fitur yang diambil
    return FeatureModel(
      meanH: meanH,
      meanS: meanS,
      meanV: meanV,
      eccentricity: eccentricity,
      metric: 0.0, // Gantikan nilai metrik yang sesuai jika diperlukan
    );
  }

  double calculateEccentricity(img.Image image) {
    double maxDistance = 0.0;
    int centerX = image.width ~/ 2;
    int centerY = image.height ~/ 2;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final grayscaleValue = img.getRed(pixel);

        // Asumsikan gambar adalah grayscale, hitung jarak dari pusat
        final distance = sqrt(pow(x - centerX, 2) + pow(y - centerY, 2));

        // Perbarui maxDistance jika jarak saat ini lebih besar
        if (distance > maxDistance) {
          maxDistance = distance;
        }
      }
    }

    // Hitung eksentrisitas (rasio jarak maksimum terhadap setengah sumbu mayor)
    double majorAxis = max(image.width, image.height).toDouble();
    double minorAxis = min(image.width, image.height).toDouble();
    return maxDistance / (majorAxis / 2);
  }

  Future<DiseaseModel?> classifyDisease(String imagePath) async {
    // Ekstraksi fitur dari gambar
    final FeatureModel featureModel = await extractFeatures(imagePath);

    // Baca data dari berkas alhamdullilah.csv
    final File csvFile = File('assets/models/alhamdullilah.csv');
    if (!await csvFile.exists()) {
      throw Exception('File alhamdullilah.csv tidak ditemukan.');
    }

    final List<List<dynamic>> csvData =
        await csvFile.readAsLines().then((lines) => lines.map((line) => line.split(',')).toList());

    // Parse CSV data into a list of FeatureModel objects
    List<FeatureModel> dataPoints = [];
    for (var row in csvData.skip(1)) {
      if (row.length == 5) {
        double meanH = double.tryParse(row[0]) ?? 0.0;
        double meanS = double.tryParse(row[1]) ?? 0.0;
        double meanV = double.tryParse(row[2]) ?? 0.0;
        double eccentricity = double.tryParse(row[3]) ?? 0.0;
        double metric = double.tryParse(row[4]) ?? 0.0;

        dataPoints.add(
          FeatureModel(
            meanH: meanH,
            meanS: meanS,
            meanV: meanV,
            eccentricity: eccentricity,
            metric: metric,
          ),
        );
      }
    }

    if (dataPoints.isEmpty) {
      return null; // Kembalikan null jika tidak ada titik data yang tersedia.
    }

    // Hitung jarak Euclidean dan temukan pertandingan terdekat
    double minDistance = double.infinity;
    DiseaseModel? closestDisease;

    for (var disease in dataPoints) {
      double distance = DistanceCalculator.euclideanDistance(featureModel, disease);
      if (distance < minDistance) {
        minDistance = distance;
        closestDisease = DiseaseModel(
          name: getDiseaseName(disease), // Set 'Disease Name' berdasarkan jenis penyakit
          description: getDiseaseDescription(disease), // Set 'Disease Description' berdasarkan jenis penyakit
        );
      }
    }

    return closestDisease;
  }

  String getDiseaseName(FeatureModel disease) {
    // Mendapatkan nama penyakit berdasarkan jenisnya
    if (disease.metric == 1) {
      return 'Kresek'; 
    } else if (disease.metric == 2) {
      return 'Blas'; 
    } else if (disease.metric == 3) {
      return 'Tungro'; 
    } else {
      return 'Tidak Dikenal'; 
    }
  }

  String getDiseaseDescription(FeatureModel disease) {
    // Mendapatkan deskripsi penyakit berdasarkan jenisnya
    if (disease.metric == 1) {
      return 'Penyakit Kresek adalah penyakit'; // Deskripsi untuk jenis penyakit 'kresek'
    } else if (disease.metric == 2) {
      return 'Penyakit Blas adalah penyakit'; // Deskripsi untuk jenis penyakit 'blas'
    } else if (disease.metric == 3) {
      return 'Penyakit Tungro adalah penyakit'; // Deskripsi untuk jenis penyakit 'tungro'
    } else {
      return 'Deskripsi Penyakit Tidak Tersedia'; // Deskripsi jika jenis penyakit tidak dikenali
    }
  }
}
