import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart';
import 'package:go_park/models/UserInfo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../key.dart';

class AuthenticationProvider with ChangeNotifier {
  String _token;
  DateTime _expiryDate;
  String _userId;
  Timer logOutTimer;
  List<UserInfo> userData = [];

//Checking Authentication Function
  bool checkauthentication() {
    if (_token != null) {
      return true;
    }
    return false;
  }

  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

//Authentication User
  Future<void> _authenticate(
      String email,
      String password,
      String urlSegment,
      String first_name,
      String last_name,
      String address,
      String card_holder,
      String security_code,
      String credit_card_number,
      String expiration_date) async {
    String url =
        'https://identitytoolkit.googleapis.com/v1/accounts:$urlSegment?key=$key';

    try {
      final response = await http.post(url,
          body: json.encode({
            'email': email,
            'password': password,
            'returnSecureToken': true
          }));

      final responseData = json.decode(response.body);

      if (responseData['error'] != null) {
        throw HttpException(responseData['error']['message']);
      }
      _token = responseData['idToken'];
      _userId = responseData['localId'];
      _expiryDate = DateTime.now().add(Duration(
          seconds: int.parse(responseData[
              'expiresIn']))); //must be calculated because the only thing we get back  is expiresIn which only contains a string but in that string we have the number the seconds So we'll have to parse that string and turn it into a number but then after turning it into a number, we have to derive a date from that. So expiry date should be a datetime object so we take the dateTime of now and add to it the amount of seconds that will expire in to generate a future date the token will expire in it

      if (urlSegment == 'signUp') {
        String url =
            'https://gopark-61782-default-rtdb.firebaseio.com/Users.json?auth=$_token';

        var response = await http.post(url,
            body: json.encode({
              'first_name': first_name,
              'last_name': last_name,
              'id': _userId,
              'email': email,
              'password': password,
              'address': address,
              'card_holder': card_holder,
              'security_code': security_code,
              'credit_card_number': credit_card_number,
              'expiration_date': expiration_date,
            }));
      }

      print('Time' + responseData['expiresIn']);

      notifyListeners();

      final prefs = await SharedPreferences
          .getInstance(); //Now this here actually returns a future which eventually will return a shared preferences instance and that is then basically your tunnel to that on device storage. So we should await that so that we don't store the future in here but the real access to shared preferences and now we can use prefs to write and read data to and from the shared preferences device storage

      final userData = json.encode({
        'token': _token,
        'userId': _userId,
        'expiryDate': _expiryDate.toIso8601String(),
      });

      //Now we can store user data here and give that a key by which we can retrieve it and that key is totally up to you, should be a string and I'll just name it user data
      prefs.setString('userData', userData); //this to write data

      print(responseData);
    } catch (error) {
      throw error;
    }
  }

  //User Signup
  Future<void> signUp(
      String email,
      String password,
      String first_name,
      String last_name,
      String address,
      String card_holder,
      String security_code,
      String credit_card_number,
      String expiration_date) async {
    return _authenticate(
        email,
        password,
        'signUp',
        first_name,
        last_name,
        address,
        card_holder,
        security_code,
        credit_card_number,
        expiration_date);
  }

  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

//User signin
  Future<void> signIn(String email, String password) async {
    return _authenticate(
        email, password, 'signInWithPassword', '', '', '', '', '', '', '');
  }

  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

//Auto Sigin
  Future<bool> tryAutoSignIn() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) {
      return false;
    }
    final extractedUserData =
        json.decode(prefs.getString('userData')) as Map<String, Object>;

    final expiryDate = DateTime.parse(extractedUserData['expiryDate']);
    if (expiryDate.isBefore(DateTime.now())) {
      return false;
    }

    _token = extractedUserData['token'];
    _userId = extractedUserData['userId'];
    _expiryDate = expiryDate;
    notifyListeners();
    _autoSignOut();
    return true;
  }

  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  void _autoSignOut() {
    if (logOutTimer != null) {
      logOutTimer.cancel();
    }
    final timeToExpiry = _expiryDate.difference(DateTime.now()).inSeconds;
    logOutTimer = Timer(Duration(seconds: timeToExpiry), SignOut);
  }

  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

//Signout Function
  Future<void> SignOut() async {
    _token = null;
    _expiryDate = null;
    _userId = null;

    if (logOutTimer != null) {
      logOutTimer.cancel();
      logOutTimer = null;
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    final userData = json.encode({
      'token': null,
      'userId': null,
      'expiryDate': null,
    });

    prefs.setString('userData', userData);
    // prefs.clear();
  }
}
