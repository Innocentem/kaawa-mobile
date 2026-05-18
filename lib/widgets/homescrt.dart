import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Clinic {
  String name;
  String category;
  String location;
  String image;
  double distance;

  Clinic(
      {required this.name,
        required this.category,
        required this.location,
        required this.distance,
        required this.image});
}

List<Clinic> clinics = [
  Clinic(
      name: "My Dental Klinik",
      category: "Dental Clinic",
      location: "Kota Bandung",
      distance: 87.65,
      image: "assets/images/pict1.webp"),
  Clinic(
      name: "Puja Medika Klinik",
      category: "General Clinic",
      location: "Kota Bandung",
      distance: 85.60,
      image: "assets/images/pict2.webp")
];

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _searchTextController = TextEditingController();

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          widget.title,
          style: TextStyle(color: Colors.black),
        ),
        elevation: 0,
        leading: IconButton(
          onPressed: () {},
          icon: Icon(
            Icons.lens,
            color: Colors.grey,
          ),
          iconSize: 40,
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.notifications, color: Colors.grey),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.settings, color: Colors.grey),
          ),
        ],
      ),
      body: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white),
        child: ListView(
          children: <Widget>[
            _searchForm(),
            SizedBox(
              height: 10,
            ),
            _homeShortcuts(),
            SizedBox(
              height: 10,
            ),
            _clinicOpen(),
            SizedBox(
              height: 10,
            ),
            _boxedList()
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Appointment',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'My Treatment',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _searchForm() {
    return CupertinoTextField(
      padding: EdgeInsets.all(10),
      controller: _searchTextController,
      placeholder: "Search",
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        color: Color(0xFFF3F7FF),
      ),
    );
  }

  Widget _homeShortcuts() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment(0, -1),
            end: Alignment(0, 1),
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.67),
              Theme.of(context).primaryColor.withOpacity(0.87),
            ]),
        borderRadius: BorderRadius.all(Radius.elliptical(5, 5)),
      ),
      padding: EdgeInsets.fromLTRB(15, 25, 15, 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _shortcut(text: "Doctor", icon: Icons.home),
          _shortcut(text: "Clinic", icon: Icons.local_hospital),
          _shortcut(text: "Treatment", icon: Icons.accessible),
          _shortcut(text: "More", icon: Icons.view_module),
        ],
      ),
    );
  }

  Widget _shortcut({required String text, required IconData icon}) {
    return Column(
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(15)),
          ),
          padding: EdgeInsets.all(5),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 40,
          ),
        ),
        SizedBox(
          height: 18,
        ),
        Text(
          text,
          style: TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _clinicOpen() {
    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            "Clinic is open",
            style: TextStyle(
                fontSize: 20,
                color: Color(0xff334B7E),
                fontWeight: FontWeight.w500),
          ),
          Material(
            child: InkWell(
              splashColor: Theme.of(context).primaryColor,
              highlightColor: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.all(Radius.circular(50)),
              onTap: () {
                _settingModalBottomSheet(context);
              },
              child: Container(
                  padding: EdgeInsets.fromLTRB(25, 10, 25, 10),
                  decoration: BoxDecoration(
                      border: Border.all(
                          width: 2, color: Theme.of(context).primaryColor),
                      borderRadius: BorderRadius.all(Radius.circular(50))),
                  child: Text(
                    "Today",
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  )),
            ),
          )
        ],
      ),
    );
  }

  Widget _boxedList() {
    return SizedBox(
      height: 220,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[...clinics.map((d) => _boxedItem(d))],
      ),
    );
  }

  Widget _boxedItem(Clinic clinic) {
    BorderRadius radius = BorderRadius.all(Radius.circular(10));
    BoxDecoration decors = BoxDecoration(
        image:
        DecorationImage(image: AssetImage(clinic.image), fit: BoxFit.fill),
        borderRadius: radius);
    Container overlay = Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment(0, -1),
              end: Alignment(0, 1),
              colors: [
                Color(0xffbfcee8).withOpacity(0.41),
                Color(0xff0a2459).withOpacity(0.60),
              ]),
          borderRadius: radius),
      width: double.infinity,
      height: double.infinity,
    );

    Widget boxedContent(Clinic clinic) {
      Widget category = Container(
        padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(50)),
            color: Theme.of(context).primaryColor),
        child: Text(
          clinic.category,
          style: TextStyle(color: Colors.white),
        ),
      );
      return Container(
        padding: EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            category,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  clinic.name,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20),
                ),
                Text(
                  clinic.location,
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(
                  height: 5,
                ),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.map,
                      color: Colors.white,
                    ),
                    SizedBox(
                      width: 3,
                    ),
                    Text(
                      "{clinic.distance} Km",
                      style: TextStyle(color: Colors.white),
                    )
                  ],
                )
              ],
            )
          ],
        ),
      );
    }

    return Container(
      height: 220,
      width: 200,
      margin: EdgeInsets.only(right: 10),
      decoration: decors,
      child: Stack(
        children: <Widget>[overlay, boxedContent(clinic)],
      ),
    );
  }

  void _settingModalBottomSheet(context) {
    showModalBottomSheet(
        context: context,
        builder: (builder) {
          return Container(
            height: 350.0,
            color: Colors.transparent, //could change this to Color(0xFF737373),
            //so you don't have to change MaterialApp canvasColor
            child: Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(15.0),
                        topRight: const Radius.circular(15.0))),
                child: Center(
                  child: Text("This is a modal sheet"),
                )),
          );
        });
  }
}
