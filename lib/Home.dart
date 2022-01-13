import 'dart:convert';
import 'package:api_cache_manager/models/cache_db_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:timer_builder/timer_builder.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:api_cache_manager/api_cache_manager.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart';

DateTime time = DateTime.now();
DateTime tomorrow = DateTime.now().add(Duration(days: 1));

String? area;
String? city;

double temp = -99;
double humid = -99;
double wind = -99;
String sunrise = "-";
String sunset = "-";
String description = "Hey! Hope you're having a nice day...";
List? hoursData = null;


class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {

  String location ='Null, Press Button';
  String Address = 'search';

  Future<Position> _getGeoLocationPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return Future.error('Location services are disabled');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        Fluttertoast.showToast(msg: 'Location permissions are denied',
            toastLength: Toast.LENGTH_LONG);
      }
    }

    if (permission == LocationPermission.deniedForever) {
      Fluttertoast.showToast(msg:
      'Location permissions are permanently denied, we cannot request permissions',
          toastLength: Toast.LENGTH_LONG);
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }
  Future<void> GetAddressFromLatLong(Position position)async {
    List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, position.longitude);
    Placemark place = placemarks[1];
    String? sublocality = place.subLocality;
    String? locality = place.locality;
    getAPIData(sublocality! , locality!);
    Address = '${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}, ${place.postalCode}';
    print(Address);
    setState(() {
      area = place.subLocality;
      city = place.locality;
      setlocationdetails();
    });
  }

  getlocationdetails() async{
    SharedPreferences local_area = await SharedPreferences.getInstance();
    SharedPreferences local_city = await SharedPreferences.getInstance();
    String? saved_area = local_area.getString("areakey");
    String? saved_city = local_city.getString("citykey");
    setState(() async {
      area = saved_area ?? "Update";
      city = saved_city ?? "Your Location!";
      if(area == "Update") {
        askforlocation();
      }
      else{
        //Get Saved Weather API data from cache memory
        var isCacheExist = await APICacheManager().isAPICacheKeyExist("Weather_Details");
        if(!isCacheExist)
          getAPIData("$area", "$city");
        else{
          var cacheData = await APICacheManager().getCacheData("Weather_Details");
          Map ApiData = jsonDecode(cacheData.syncData);
          updateAPIdata(ApiData);
        }
      }
    });
  }

  setlocationdetails() async{
    SharedPreferences local_area = await SharedPreferences.getInstance();
    SharedPreferences local_city = await SharedPreferences.getInstance();
    local_area.setString("areakey", area!);
    local_city.setString("citykey", city!);
  }

  askforlocation() async{
    Position position = await _getGeoLocationPosition();
    location = 'Lat: ${position.latitude} , Long: ${position.longitude}';
    GetAddressFromLatLong(position);
  }

  updateAPIdata(Map ApiData){
    String tempAddress = ApiData["resolvedAddress"];
    List<String> AddressSplit = tempAddress.split(", ");
    setState(() {
      temp = ApiData["currentConditions"]["temp"];
      humid = ApiData["currentConditions"]["humidity"];
      wind = ApiData["currentConditions"]["windspeed"];
      description = ApiData["days"][0]["description"];
      sunrise = ApiData["currentConditions"]["sunrise"];
      sunset = ApiData["currentConditions"]["sunset"];
      hoursData = ApiData["days"][0]["hours"];
      area = AddressSplit[0];
      city = AddressSplit[1];
    });
  }

  void getAPIData(String sublocality,String locality) async{
    Response response = await get(Uri.parse("https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/$sublocality%2C%20$locality/${time.year}-${time.month}-${time.day}/${tomorrow.year}-${tomorrow.month}-${tomorrow.day}?unitGroup=metric&key=QPHZKJMCLVZMJA5RMBNLHBTU7&include=hours%2Ccurrent"));
    Map ApiData = jsonDecode(response.body);
    updateAPIdata(ApiData);
    //Saving Weather API data in cache memory
    APICacheManager().emptyCache();
    APICacheDBModel cacheDBModel = new APICacheDBModel(key: "Weather_Details", syncData: response.body);
    await APICacheManager().addCacheData(cacheDBModel);
  }

  @override
  void initState() {
    super.initState();
    getlocationdetails();
  }


  @override
  Widget build(BuildContext context) {
    var device = MediaQuery.of(context).size;
    double height = device.height;
    TextEditingController location_text = TextEditingController();

    return SafeArea(
      child: Scaffold(
        backgroundColor: Color(0xff222830),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                height: 60,
                width: device.width,
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Container(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(width: 13),
                        GestureDetector(
                            onTap: () {askforlocation();},
                            child: Icon(Icons.location_on,color: Color(0xff222830),)),
                        SizedBox(width: 13),
                        Expanded(
                            child: TextFormField(
                              controller: location_text,
                              onFieldSubmitted: (_){
                                print("This is ${location_text.text}");
                                getAPIData("${location_text.text}", "");
                              },
                              maxLines: 1,
                              style: TextStyle(color: Colors.white),
                              cursorColor: Colors.white,
                              decoration: InputDecoration(
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                hintStyle: TextStyle(
                                  height: 1,
                                  fontSize: 18,
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w400,
                                ),
                                hintText: area == "Update" || area == null ? "Location" : "${area}, ${city}",
                              ),
                            )
                        )
                      ],
                    ),
                    width: device.width,
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),
              Container(
                height: device.height * 0.88,
                width: device.width,
                child: Stack(
                  children: [
                    Positioned(
                      child: area == null ? Container() : Text(area == "Update" ? "${area}" : "${area}" + ",",
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            color: Colors.white
                        ),),
                      top: 30,
                      left: 10,),
                    Positioned(
                      child: city == null ? Container() : Text("${city}",
                        style: TextStyle(
                            fontSize: 31,
                            fontWeight: FontWeight.w400,
                            color: Color(0xfffd7014),
                            letterSpacing: 2
                        ),),
                      top: 70,
                      left: 10,),
                    Positioned(
                        top: 130,
                        left: 20,
                        child: Container(
                          width: device.width * 0.6,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              climateValue("Temp",temp,"°C"),
                              climateValue("Humid",humid,"g/km"),
                              climateValue("Wind",wind,"km/h"),
                            ],
                          ),
                        )),
                    Positioned(
                      child: Container(
                        width: 230,
                        child: Text(description,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              letterSpacing: 1,
                              height: 1.4
                          ),),
                      ),
                      bottom: device.height * 0.49,
                      left: 20,
                    ),
                    Positioned(
                      child: Container(
                        height: device.height * 0.245,//210,
                        width: 104,
                        child: Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)
                          ),
                          color: Color(0xfffd7014),
                        ),
                      ),
                      top: 18,
                      right: 8,
                    ),
                    Positioned(
                      child: Container(
                        height: device.height * 0.24,//206,
                        width: 100,
                        child: Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)
                          ),
                          color: Color(0xff393e46),
                        ),
                      ),
                      top: 20,
                      right: 10,
                    ),
                    Positioned(
                        top: 34,
                        right: 22,
                        child: timer()),
                    Positioned(
                      bottom: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                            height: device.height * 0.47,
                            width: device.width * 0.95,
                            decoration: BoxDecoration(
                                color: Color(0xfffd7014),
                                borderRadius: BorderRadius.circular(15)
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                    top: 0,
                                    child: Container(
                                      height: height * 0.2,
                                      width: device.width * 0.95,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Container(
                                            height: height * 0.14,width: 150,
                                            child: sundetails("Sunrise Time", height, sunrise, "Assets/sunrise.png"),
                                          ),
                                          Container(
                                            height: height * 0.14,width: 150,
                                            child: sundetails("Sunset Time", height, sunset, "Assets/sunset.png"),
                                          ),
                                        ],
                                      ),
                                    )
                                ),

                                Positioned(
                                  top: (height * 0.14) + 45,
                                  left: 8,
                                  child: Row(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                            color: Color(0xff393e40),
                                            borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(15),
                                                bottomLeft: Radius.circular(15)
                                            )
                                        ),
                                        width: device.width * 0.2,
                                        height: device.height * 0.25,
                                        //color: Color(0xff393e46),
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 14.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text("Time",style: TextStyle(fontSize: 20,fontWeight: FontWeight.w600,color: Colors.white)),
                                              SizedBox(height: 25),
                                              Text("Temp",style: TextStyle(fontSize: 20,fontWeight: FontWeight.w600,color: Colors.white)),
                                              SizedBox(height: 25),
                                              Text("Humid",style: TextStyle(fontSize: 20,fontWeight: FontWeight.w600,color: Colors.white)),
                                              SizedBox(height: 25),
                                              Text("Wind",style: TextStyle(fontSize: 20,fontWeight: FontWeight.w600,color: Colors.white)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                          decoration: BoxDecoration(
                                              color: Color(0xff393e40),
                                              borderRadius: BorderRadius.only(
                                                  topRight: Radius.circular(15),
                                                  bottomRight: Radius.circular(15)
                                              )
                                          ),
                                          width: device.width * 0.706,
                                          height: device.height * 0.25,
                                          //color: Color(0xff393e46),
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: 24,
                                            itemBuilder: (context, index)
                                                { return //wholeDayStat(24, 23, 22, 21);
                                                  hoursData == null ? wholeDayStat( -99, -99 , -99 , index ) :
                                                  wholeDayStat( hoursData![index]["temp"], hoursData![index]["humidity"] , hoursData![index]["windspeed"] , index );
                                                },
                                          )
                                      )
                                    ],
                                  ),
                                )
                              ],
                            )
                        ),
                      ),
                    ),
                    Positioned(
                      child: Image.asset( time.hour>=5 && time.hour<18 ? "Assets/sunny.png" : "Assets/full_moon.png",
                        width: device.height * 0.25,
                        height: device.height * 0.25,
                        scale: 0.85,
                      ),
                      right: -30,
                      bottom: height * 0.378,
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Column wholeDayStat(dynamic hourTemp,dynamic hourHumid,dynamic hourWind, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(index < 10 ? "0$index:00" : "$index:00"  ,style: TextStyle(fontSize: 18,fontWeight: FontWeight.w500,color: Colors.white)),
        SizedBox(height: 25,width: 70),
        Text(hourTemp == -99 || hourTemp == null ? "-" : "${hourTemp}°" ,style: TextStyle(fontSize: 18,fontWeight: FontWeight.w400,color: Colors.white)),
        SizedBox(height: 25),
        Text(hourHumid == -99 || hourHumid == null ? "-" : "${hourHumid}",style: TextStyle(fontSize: 18,fontWeight: FontWeight.w400,color: Colors.white)),
        SizedBox(height: 25),
        Text(hourWind == -99 || hourWind == null ? "-" : "${hourWind}",style: TextStyle(fontSize: 18,fontWeight: FontWeight.w400,color: Colors.white)),
      ],
    );
  }

  Column sundetails(String sun, double height, String suntime, String address) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Image.asset(address,height: height * 0.08,width: height * 0.08,),
        Text(sun),
        Text(suntime,style: TextStyle(fontSize: 20,fontWeight: FontWeight.w600))
      ],
    );
  }

  Container climateValue(String title,double value,String unit) {
    return Container(
      height: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              )),
          Text(value == -99 ? "-" : "$value",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              )),
          Text(unit,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ))
        ],
      ),
    );
  }
}
 // Clock
class timer extends StatefulWidget {
  const timer({Key? key}) : super(key: key);

  @override
  _timerState createState() => _timerState();
}

class _timerState extends State<timer> {

  DateTime getSystemTime(){
    DateTime time = DateTime.now();
    return time;
  }

  @override
  Widget build(BuildContext context) {
    var device = MediaQuery.of(context).size;
    return TimerBuilder.periodic(Duration(seconds: 1), builder: (context){
      time = getSystemTime();
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(time.hour > 12 ? (time.hour-12 < 10 ? "0${time.hour-12}":"${time.hour-12}") : (time.hour < 10 ? "0${time.hour}" : "${time.hour}"),style: TextStyle(fontSize: 70,color: Colors.white70,height: device.height * 0.0011),),
          Text(time.minute < 10 ? "0${time.minute}" : "${time.minute}",style: TextStyle(fontSize: 70,color: Colors.white70,height: device.height * 0.0011),),
          Text(time.hour < 12 ? "AM" : "PM",style: TextStyle(fontSize: 50,color: Colors.white70,height: device.height * 0.0012)),
        ],
      );
    });
  }
}