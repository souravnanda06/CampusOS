import 'dart:convert';
import '../models/coupon_model.dart';
import '../../core/network/api_client.dart';

class CouponService {
  final ApiClient _apiClient;

  CouponService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  // Fetch coupons from backend
  Future<List<CouponModel>> getUserCoupons(String userId) async {
    try {
      final response = await _apiClient.get('/coupons/$userId');
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CouponModel.fromMap(json, json['id'])).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Redeem a coupon
  Future<void> useCoupon(String couponId) async {
    try {
      final response = await _apiClient.post(
        '/coupons/use',
        body: {'couponId': couponId},
      );
      if (response.statusCode != 200) {
        throw jsonDecode(response.body)['message'] ?? 'Failed to redeem coupon';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  // Get active coupon count
  Future<int> getCouponCount(String userId) async {
    final coupons = await getUserCoupons(userId);
    return coupons
        .where((c) => !c.isUsed && c.expiryDate.isAfter(DateTime.now()))
        .length;
  }
}
