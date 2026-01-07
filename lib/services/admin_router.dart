import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/admin_screen.dart';
import '../screens/admin/grid_designer_screen.dart';

class AdminRouter {
  static final routes = [
    GoRoute(
      path: '/admin',
      name: 'admin',
      builder: (context, state) => const AdminScreen(),
      routes: [
        GoRoute(
          path: 'create',
          name: 'create-grid',
          builder: (context, state) => const GridDesignerScreen(),
        ),
        GoRoute(
          path: 'edit/:gridId',
          name: 'edit-grid',
          builder: (context, state) {
            final gridId = state.pathParameters['gridId'];
            return GridDesignerScreen(gridId: gridId);
          },
        ),
      ],
    ),
  ];
}

void navigateToCreateGrid(BuildContext context) {
  context.goNamed('create-grid');
}

void navigateToEditGrid(BuildContext context, String gridId) {
  context.goNamed('edit-grid', pathParameters: {'gridId': gridId});
}

void navigateToAdmin(BuildContext context) {
  context.goNamed('admin');
}
