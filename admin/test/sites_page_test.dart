import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeray_lens_admin/features/sites/application/site_controller.dart';
import 'package:seeray_lens_admin/features/sites/presentation/sites_page.dart';
import 'package:seeray_lens_admin/features/workspaces/application/workspace_controller.dart';

void main() {
  testWidgets('renders the current workspace site list', (tester) async {
    final container = ProviderContainer(
      overrides: [
        currentWorkspaceProvider.overrideWith(CurrentWorkspaceController.new),
        sitesProvider.overrideWith(_FakeSitesController.new),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(currentWorkspaceProvider.notifier)
        .select(const Workspace(id: 'w1', name: 'Demo', role: 'owner'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SitesPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Demo sites'), findsOneWidget);
    expect(find.text('No sites yet. Create your first site.'), findsOneWidget);
  });

  testWidgets('create site dialog presents retention defaults', (tester) async {
    final container = ProviderContainer(
      overrides: [
        currentWorkspaceProvider.overrideWith(CurrentWorkspaceController.new),
        sitesProvider.overrideWith(_FakeSitesController.new),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(currentWorkspaceProvider.notifier)
        .select(const Workspace(id: 'w1', name: 'Demo', role: 'owner'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SitesPage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Create site'));
    await tester.pumpAndSettle();
    expect(find.text('Raw retention days'), findsOneWidget);
    expect(find.text('Aggregate retention days'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('730'), findsOneWidget);
    expect(
      find.textContaining('Raw events are automatically deleted'),
      findsOneWidget,
    );
    expect(find.text('IP acquisition method'), findsOneWidget);
    expect(find.text('System default (environment)'), findsOneWidget);
  });

  testWidgets('create site dialog supports HTTP header preset and custom header', (tester) async {
    final container = ProviderContainer(
      overrides: [
        currentWorkspaceProvider.overrideWith(CurrentWorkspaceController.new),
        sitesProvider.overrideWith(_FakeSitesController.new),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(currentWorkspaceProvider.notifier)
        .select(const Workspace(id: 'w1', name: 'Demo', role: 'owner'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SitesPage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Create site'));
    await tester.pumpAndSettle();

    // Scroll to IP acquisition dropdown and tap it
    await tester.ensureVisible(find.text('System default (environment)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('System default (environment)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HTTP request header').last);
    await tester.pumpAndSettle();

    // Preset dropdown should appear with default X-Forwarded-For
    await tester.ensureVisible(find.text('HTTP header preset'));
    await tester.pumpAndSettle();
    expect(find.text('HTTP header preset'), findsOneWidget);
    expect(find.text('X-Forwarded-For'), findsOneWidget);

    // Select 'Custom header…'
    await tester.tap(find.text('X-Forwarded-For'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom header…').last);
    await tester.pumpAndSettle();

    // Custom header name field should appear
    await tester.ensureVisible(find.text('Custom header name'));
    expect(find.text('Custom header name'), findsOneWidget);
  });
}

class _FakeSitesController extends SitesController {
  @override
  Future<List<Site>> build() async => const [];
}
