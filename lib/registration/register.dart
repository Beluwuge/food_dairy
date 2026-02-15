import 'package:flutter/material.dart';
import 'package:food_dairy/services/shared_preference_helper.dart';
import 'package:food_dairy/main.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final accountName = TextEditingController();
  final accountPass = TextEditingController();
  final cfmPass = TextEditingController();
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
        title: Text("Create Account"),
      ),
      body: Container(
        padding: EdgeInsets.all(23.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
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
            TextField(
              controller: cfmPass,
              decoration: InputDecoration(
                icon: Icon(Icons.confirmation_num_outlined),
                labelText: "Confirm Password",
              ),
              obscureText: true,
            ),
            OutlinedButton(
              onPressed: () async {
                String nameInput = accountName.text;
                String passInput = accountPass.text;
                String cfmInput = cfmPass.text;

                Map<String, dynamic> userData = await SharedPreferenceHelper.getMap("userlist");

                if(nameInput.isEmpty | passInput.isEmpty | cfmInput.isEmpty){
                  updateDisplay("username or Password cannot be empty.");
                }
                else if(userData.containsKey(nameInput)){
                  updateDisplay("Username used");
                }
                else if(cfmInput != passInput){
                  updateDisplay("Password and confirm password does not match");
                }
                else {
                  updateDisplay("Registered successfully");

                  userData[nameInput] = [passInput, false];

                  await SharedPreferenceHelper.saveMap("userlist", userData);

                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>
                          LoginScreen()));
                }
              },
              child: Text("Create New Account"),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) =>
                        LoginScreen()));
              },
              child: Text("Cancel"),
            ),
          ],
        ),
      ),
    );
  }
}
