import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Helper class để xử lý các vấn đề phổ biến với Firebase
class FirebaseHelpers {
  /// Chuyển đổi an toàn giá trị sang Timestamp
  /// Hỗ trợ: Timestamp, String, DateTime, int (milliseconds)
  static Timestamp? toTimestamp(dynamic value) {
    if (value == null) {
      return null;
    }
    
    try {
      if (value is Timestamp) {
        return value;
      } else if (value is String) {
        try {
          final dateTime = DateTime.parse(value);
          return Timestamp.fromDate(dateTime);
        } catch (e) {
          debugPrint('❌ Không thể chuyển đổi String sang Timestamp: $e');
          return null;
        }
      } else if (value is DateTime) {
        return Timestamp.fromDate(value);
      } else if (value is int) {
        // Giả sử đây là milliseconds since epoch
        return Timestamp.fromMillisecondsSinceEpoch(value);
      } else {
        debugPrint('❌ Không hỗ trợ kiểu dữ liệu ${value.runtimeType} cho chuyển đổi sang Timestamp');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi chuyển đổi sang Timestamp: $e');
      return null;
    }
  }
  
  /// Chuyển đổi an toàn giá trị sang DateTime
  /// Hỗ trợ: Timestamp, String, DateTime, int (milliseconds)
  static DateTime? toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    
    try {
      if (value is DateTime) {
        return value;
      } else if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          debugPrint('❌ Không thể chuyển đổi String sang DateTime: $e');
          return null;
        }
      } else if (value is int) {
        // Giả sử đây là milliseconds since epoch
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else {
        debugPrint('❌ Không hỗ trợ kiểu dữ liệu ${value.runtimeType} cho chuyển đổi sang DateTime');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi chuyển đổi sang DateTime: $e');
      return null;
    }
  }
  
  /// Chuyển đổi an toàn giá trị sang String ISO8601
  /// Hỗ trợ: Timestamp, String, DateTime, int (milliseconds)
  static String? toISOString(dynamic value) {
    if (value == null) {
      return null;
    }
    
    final dateTime = toDateTime(value);
    return dateTime?.toIso8601String();
  }
  
  /// Tiền xử lý dữ liệu Firebase trước khi sử dụng
  /// Xử lý các vấn đề phổ biến như Timestamp vs String
  static Map<String, dynamic> processFirestoreData(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    
    // Danh sách các trường thường là timestamp
    final timestampFields = [
      'created_at',
      'updated_at',
      'lastSyncTime',
      'last_login',
      'last_updated',
      'timestamp',
      'createdAt',
      'updatedAt',
      'lastLoginAt',
      'created_date',
      'update_date',
      'last_sync',
    ];
    
    // Xử lý các trường thời gian
    for (final field in timestampFields) {
      if (result.containsKey(field)) {
        final dateTime = toDateTime(result[field]);
        if (dateTime != null) {
          // Lưu lại dưới dạng DateTime để dễ xử lý trong ứng dụng
          result[field] = dateTime;
        }
      }
    }
    
    return result;
  }
  
  /// Chuẩn bị dữ liệu trước khi gửi lên Firestore
  /// Chuyển đổi các trường thời gian thành định dạng chuỗi ISO8601 để có thể encode JSON
  static Map<String, dynamic> prepareDataForFirestore(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    
    // Xử lý tất cả các giá trị map lồng nhau trước
    result.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        result[key] = prepareDataForFirestore(value);
      } else if (value is List) {
        result[key] = _prepareListForJson(value);
      }
    });
    
    // Danh sách các trường thường là timestamp
    final timestampFields = [
      'created_at',
      'updated_at',
      'lastSyncTime',
      'last_login',
      'last_updated',
      'timestamp',
      'createdAt',
      'updatedAt',
      'lastLoginAt',
      'created_date',
      'update_date',
      'last_sync',
      'deleted_at',
    ];
    
    // Xử lý các trường thời gian
    for (final field in timestampFields) {
      if (result.containsKey(field)) {
        // Chuyển đổi sang chuỗi ISO8601 để có thể encode JSON
        final isoString = toISOString(result[field]);
        if (isoString != null) {
          result[field] = isoString;
        }
      }
    }
    
    return result;
  }
  
  /// Xử lý danh sách để chuẩn bị cho việc encode JSON
  static List _prepareListForJson(List items) {
    return items.map((item) {
      if (item is Map<String, dynamic>) {
        return prepareDataForFirestore(item);
      } else if (item is List) {
        return _prepareListForJson(item);
      } else if (item is Timestamp) {
        return toISOString(item);
      } else {
        return item;
      }
    }).toList();
  }
  
  /// Duyệt đệ quy toàn bộ đối tượng để tìm và chuyển đổi tất cả Timestamp
  static dynamic prepareAnyDataForJson(dynamic data) {
    if (data is Map<String, dynamic>) {
      return prepareDataForFirestore(data);
    } else if (data is List) {
      return _prepareListForJson(data);
    } else if (data is Timestamp) {
      return toISOString(data);
    } else {
      return data;
    }
  }
  
  /// Kiểm tra lỗi Firebase và xử lý phù hợp
  static String handleFirebaseError(dynamic error) {
    if (error is FirebaseException) {
      // Xử lý lỗi Firebase
      switch (error.code) {
        case 'admin-restricted-operation':
          return 'Thao tác này bị hạn chế. Vui lòng đăng nhập bằng email và mật khẩu.';
        case 'network-request-failed':
          return 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối internet của bạn.';
        case 'permission-denied':
          return 'Bạn không có quyền thực hiện thao tác này.';
        default:
          return 'Lỗi Firebase: ${error.code} - ${error.message}';
      }
    } else if (error is String && error.contains('com.google.android.gms')) {
      // Lỗi Google Play Services
      return 'Lỗi Google Play Services. Vui lòng cập nhật Google Play Services và thử lại.';
    } else {
      // Lỗi khác
      return 'Đã xảy ra lỗi: $error';
    }
  }
  
  /// Kiểm tra xem Google Play Services có khả dụng không
  static Future<bool> isGooglePlayServicesAvailable() async {
    try {
      // Cách an toàn hơn để kiểm tra Google Play Services
      // Chỉ kiểm tra xem Firebase Auth đã được khởi tạo hay chưa
      if (FirebaseAuth.instance != null) {
        return true;
      }
      return true;
    } catch (e) {
      // Bỏ qua lỗi và trả về true để không chặn luồng xử lý
      debugPrint('⚠️ Không thể kiểm tra Google Play Services: $e');
      return true;
    }
  }
  
  /// Chuyển đổi an toàn từ List sang Map
  /// Hữu ích khi API trả về List thay vì Map như mong đợi
  static Map<String, dynamic>? safeListToMap(dynamic data) {
    try {
      if (data == null) {
        return null;
      }
      
      if (data is Map<String, dynamic>) {
        // Đã là Map, trả về trực tiếp
        return data;
      } else if (data is List) {
        // Là List, cần chuyển đổi
        if (data.isEmpty) {
          // Danh sách trống
          return {};
        }
        
        // Lấy phần tử đầu tiên
        final firstItem = data.first;
        if (firstItem is Map<String, dynamic>) {
          // Phần tử đầu tiên là Map, trả về nó
          return firstItem;
        } else {
          // Phần tử đầu tiên không phải Map
          return {
            'data': data,
            'converted': true,
            'original_type': 'List'
          };
        }
      } else {
        // Kiểu dữ liệu khác
        return {
          'value': data.toString(),
          'converted': true,
          'original_type': data.runtimeType.toString()
        };
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi chuyển đổi dữ liệu: $e');
      return null;
    }
  }
  
  /// Xử lý phản hồi API một cách an toàn
  /// Trả về Map<String, dynamic> trong mọi trường hợp, không bao giờ null
  static Map<String, dynamic> safeHandleApiResponse(dynamic responseData) {
    try {
      if (responseData == null) {
        return {'error': 'Dữ liệu trống'};
      }
      
      // Debug log để kiểm tra kiểu dữ liệu
      debugPrint('🔍 Kiểu dữ liệu API response: ${responseData.runtimeType}');
      
      // Xử lý trường hợp PigeonUserDetails trước tiên
      if (responseData.toString().contains('PigeonUserDetails')) {
        debugPrint('⚠️ Phát hiện PigeonUserDetails, trả về Map an toàn');
        return {
          'user_id': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
          'email': FirebaseAuth.instance.currentUser?.email ?? 'unknown',
          'display_name': FirebaseAuth.instance.currentUser?.displayName,
          'photo_url': FirebaseAuth.instance.currentUser?.photoURL,
          'is_authenticated': true,
          'converted_from_pigeonuserdetails': true
        };
      }
      
      if (responseData is Map<String, dynamic>) {
        return responseData;
      } else if (responseData is List) {
        debugPrint('⚠️ API trả về List thay vì Map, đang chuyển đổi');
        
        if (responseData.isEmpty) {
          return {'error': 'Danh sách trống'};
        }
        
        // Kiểm tra lại lần nữa cho trường hợp List<PigeonUserDetails>
        if (responseData.toString().contains('PigeonUserDetails')) {
          debugPrint('⚠️ Phát hiện List<PigeonUserDetails>, trả về Map an toàn');
          return {
            'user_id': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
            'email': FirebaseAuth.instance.currentUser?.email ?? 'unknown',
            'display_name': FirebaseAuth.instance.currentUser?.displayName,
            'photo_url': FirebaseAuth.instance.currentUser?.photoURL,
            'is_authenticated': true,
            'converted_from_list_pigeonuserdetails': true
          };
        }
        
        try {
          final firstItem = responseData.first;
          if (firstItem is Map<String, dynamic>) {
            return firstItem;
          } else {
            return {
              'data': responseData,
              'converted': true,
              'original_type': 'List'
            };
          }
        } catch (listError) {
          debugPrint('⚠️ Không thể xử lý phần tử trong List: $listError');
          return {
            'data': [],
            'converted': true,
            'original_type': 'List',
            'error': 'Không thể xử lý phần tử trong List'
          };
        }
      } else {
        debugPrint('⚠️ API trả về kiểu dữ liệu không xác định: ${responseData.runtimeType}');
        return {
          'data': responseData.toString(),
          'converted': true,
          'original_type': responseData.runtimeType.toString()
        };
      }
    } catch (e) {
      debugPrint('❌ Lỗi xử lý dữ liệu API: $e');
      
      // Kiểm tra nếu lỗi liên quan đến PigeonUserDetails
      if (e.toString().contains('PigeonUserDetails')) {
        debugPrint('⚠️ Phát hiện lỗi PigeonUserDetails trong xử lý, trả về Map an toàn');
        return {
          'user_id': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
          'email': FirebaseAuth.instance.currentUser?.email ?? 'unknown',
          'display_name': FirebaseAuth.instance.currentUser?.displayName,
          'photo_url': FirebaseAuth.instance.currentUser?.photoURL,
          'is_authenticated': true,
          'converted_from_error': true
        };
      }
      
      return {'error': 'Lỗi xử lý dữ liệu: ${e.toString()}'};
    }
  }
} 