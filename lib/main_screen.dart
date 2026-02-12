import 'package:flutter/material.dart';
import 'package:kwf_energiemonitor/menu_items.dart';
import 'package:kwf_energiemonitor/user.dart';
import 'package:kwf_energiemonitor/login_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _activePage = 0; //Defaulting to Home

  void _changePage(int index) {
    setState(() {
      _activePage = index;
    });
  }

  @override
  //Todo: Style the icons
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).canvasColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          title: const Text('Energiemonitor',
              style: TextStyle(color: Colors.white)),
          actions: [
            AppUser().isLoggedIn
                ? IconButton(
                    icon: const Icon(Icons.logout),
                    color: Colors.white,
                    tooltip: 'Ausloggen',
                    onPressed: () async {
                      await AppUser().signOut();
                      setState(() {
                        AppUser();
                      });
                    })
                : IconButton(
                    icon: const Icon(Icons.login),
                    color: Colors.white,
                    tooltip: 'Einloggen',
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const LoginScreen()));
                      setState(() {
                        AppUser();
                      });
                    })
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: <BottomNavigationBarItem>[
            ...mainScreenPages.map((page) {
              return BottomNavigationBarItem(
                  icon: Icon(page.menuIcon), label: page.label);
            })
          ],
          currentIndex: _activePage,
          onTap: _changePage,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
        ),
        body: FutureBuilder(
          future: AppUser().init(), // Initialize user once on app startup
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator()); // Loading state
            } else if (snapshot.hasError) {
              return Text(
                  'Error: ${snapshot.error}'); // Todo: Beautiful error handling
            } else {
              return mainScreenPages[_activePage].widget;
            }
          },
        ));
  }
}
