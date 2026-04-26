import 'package:flutter/material.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final appRouter = sl<AppRouter>();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);

        if (!currentFocus.hasPrimaryFocus &&
            currentFocus.focusedChild != null) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: MaterialApp.router(
        title: 'TGC Carpets',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: appRouter.router,
        builder: (context, child) {
          // Global BlocObserver can be wired here if needed
          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }
}
