import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgc_client/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:tgc_client/features/auth/presentation/pages/general_login_view.dart';
import 'package:tgc_client/features/auth/presentation/pages/label_print_login_view.dart';
import '../../../../core/di/injection.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLabelPrintingTerminal = false;

  @override
  void initState() {
    super.initState();
    _loadSettings().then((value) {
      setState(() {
        _isLabelPrintingTerminal = value;
      });
    });
  }

  Future<bool> _loadSettings() async {
    return (await SharedPreferences.getInstance())
            .getBool('isLabelPrintingTerminal') ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<AuthBloc>(),
      child: _isLabelPrintingTerminal
          ? const LabelLoginView()
          : const GeneralLoginView(),
    );
  }
}
