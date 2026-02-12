import 'package:flutter/material.dart';
import 'services/shared_preference_helper.dart';
import 'main.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late Map<String, dynamic>userData = {};
  String currentUser = "";
  String displayTxt = "Change password?";

  void updateDisplay(String txt) {
    setState(() {
      displayTxt = txt;
    });
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async{
    userData = await SharedPreferenceHelper .getMap("userlist");
    setState(() {
      userData.forEach(
              (key, value){
            if(value[1] == true){
              currentUser = key;
            }
          });

      if(currentUser.isEmpty && userData.isNotEmpty){
        currentUser = userData.keys.first;
      }
    });
  }

  final accountOldPass = TextEditingController();
  final accountNewPass = TextEditingController();
  final accountCfmPass = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: Text("Change password"),
      ),
      body: Container(
        padding: EdgeInsets.all(23.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: 20,),
            Text("Username: "+currentUser),
            SizedBox(height: 20,),
            Text(displayTxt),
            TextField(
              controller: accountOldPass,
              decoration: InputDecoration(
                icon: Icon(Icons.password),
                labelText: "Password",
              ),
              obscureText: true,
            ),
            TextField(
              controller: accountNewPass,
              decoration: InputDecoration(
                icon: Icon(Icons.password),
                labelText: "New Password",
              ),
              obscureText: true,
            ),
            TextField(
              controller: accountCfmPass,
              decoration: InputDecoration(
                icon: Icon(Icons.confirmation_num_outlined),
                labelText: "Confirm Password",
              ),
              obscureText: true,
            ),
            OutlinedButton(
              onPressed: () async {
                String passInput = accountOldPass.text;
                String newPassInput = accountNewPass.text;
                String cfmInput = accountCfmPass.text;

                if(newPassInput.isEmpty | passInput.isEmpty | cfmInput.isEmpty){
                  updateDisplay("Passwords cannot be empty.");
                }
                else if(userData[currentUser][0] != passInput){
                  updateDisplay("Wrong password");
                }
                else if(newPassInput != cfmInput){
                  updateDisplay("New password and confirm password does not match");
                }
                else if(passInput == newPassInput){
                  updateDisplay("New password should not be the same as old password");
                }
                else {
                  updateDisplay("Updated successfully");

                  userData[currentUser][0] = newPassInput;

                  await SharedPreferenceHelper.saveMap("userlist", userData);

                  userData[currentUser][1] = false;

                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>
                          MyLoginPage(title: "Login Page")));
                }
              },
              child: Text("Update"),
            ),
            OutlinedButton(
              onPressed: () {
                userData[currentUser][1] = false;

                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) =>
                        MyLoginPage(title: "Login Page")));
              },
              child: Text("Log out"),
            ),
          ],

        ),
      ),
    );
  }
}
