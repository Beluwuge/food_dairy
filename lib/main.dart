import 'package:flutter/material.dart';
import 'services/shared_preference_helper.dart';
import 'package:food_dairy/registration/register.dart';
import 'welcome.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Revision',
      debugShowCheckedModeBanner: false,

      home: const MyLoginPage(title: 'MockTest'),
    );
  }
}

class MyLoginPage extends StatefulWidget {
  const MyLoginPage({super.key, required this.title});

  final String title;

  @override
  State<MyLoginPage> createState() => _MyLoginPageState();
}

class _MyLoginPageState extends State<MyLoginPage> {
  final accountName = TextEditingController();
  final accountPass = TextEditingController();
  String displayTxt = "";

  void updateDisplay(String txt) {
    setState(() {
      displayTxt = txt;
    });
  }

  // Insert your codes here

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: Text(widget.title),
      ),
      body: Container(
        padding: EdgeInsets.all(23.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Text(displayTxt),
            TextField(
              controller: accountName,
              decoration: InputDecoration(
                icon: Icon(Icons.person),
                labelText: "Account Name",
              ),
            ),
            TextField(
              controller: accountPass,
              decoration: InputDecoration(
                icon: Icon(Icons.password),
                labelText: "Account Password",
              ),
              obscureText: true,
            ),
            OutlinedButton(
              onPressed: () async{
                String nameInput = accountName.text;
                String passInput = accountPass.text;

                Map<String, dynamic> userData = await SharedPreferenceHelper.getMap("userlist");

                if(nameInput.isEmpty | passInput.isEmpty){
                  updateDisplay("username or Password cannot be empty.");
                }
                else if(!userData.containsKey(nameInput)){
                  updateDisplay("Wrong username");
                }
                else if(userData[nameInput][0] != passInput){
                  updateDisplay("Wrong password");
                }
                else{
                  updateDisplay("Login successfully");

                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => WelcomePage()));
                }

              },
              child: Text("Account Sign In"),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegistrationPage()));

              },
              child: Text("Register Profile"),
            ),
          ],
        ),
      ),
    );
  }
}
