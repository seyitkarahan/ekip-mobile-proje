import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// AUTH
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';

// MAIN PAGES
import '../features/home/home_page.dart';
import '../features/learn/learn_page.dart';
import '../features/leaderboard/leaderboard_page.dart';
import '../features/lessons/lessons_page.dart';
import '../features/lessons/module_lessons_page.dart';
import '../features/profile/profile_page.dart';

// LESSON FLOW
import '../features/learn/lesson_learn_page.dart';
import '../features/learn/sentence_translate_page.dart';

// QUIZ
import '../features/quiz/quiz_page.dart';
import '../features/quiz/pages/word_quiz_page.dart';
import '../features/quiz/pages/review_quiz_page.dart';
import '../features/quiz/lesson_quiz_page.dart';
import '../features/quiz/result_page.dart';
import '../features/quiz/module_exam_page.dart';

// BADGES (senin projende varsa)
import '../features/profile/badges_page.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(
      ref.read(firebaseAuthProvider).authStateChanges(),
    ),
    redirect: (context, state) {
      final isAuthRoute =
          state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (authAsync.isLoading) return null;

      final user = authAsync.value;

      if (user == null) {
        return isAuthRoute ? null : '/login';
      }
      if (isAuthRoute) return '/home';

      return null;
    },
    routes: [
      // AUTH
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterPage()),

      // HOME & MAIN
      GoRoute(path: '/home', builder: (c, s) => const HomePage()),
      GoRoute(path: '/learn', builder: (c, s) => const LearnPage()),
      GoRoute(path: '/leaderboard', builder: (c, s) => const LeaderboardPage()),
      GoRoute(path: '/profile', builder: (c, s) => const ProfilePage()),
      GoRoute(path: '/lessons', builder: (c, s) => const LessonsPage()),

      // QUIZ PAGES (genel)
      GoRoute(path: '/quiz', builder: (c, s) => const QuizPage()),
      GoRoute(path: '/word-quiz', builder: (c, s) => const WordQuizPage()),
      GoRoute(path: '/review', builder: (c, s) => const ReviewQuizPage()),

      // BADGES
      GoRoute(path: '/badges', builder: (c, s) => const BadgesPage()),

      // MODÜL İÇİ DERSLER
      GoRoute(
        path: '/module-lessons/:moduleId',
        builder: (context, state) {
          final moduleId = state.pathParameters['moduleId']!;
          final title = state.uri.queryParameters['title'] ?? 'Modül';
          final description = state.uri.queryParameters['description'] ?? '';
          return ModuleLessonsPage(
            moduleId: moduleId,
            moduleTitle: title,
            moduleDescription: description,
          );
        },
      ),

      // MODÜL SINAVI
      GoRoute(
        path: '/module-exam/:moduleId',
        builder: (context, state) {
          final moduleId = state.pathParameters['moduleId']!;
          final title = state.uri.queryParameters['title'] ?? 'Modül Sınavı';
          return ModuleExamPage(
            moduleId: moduleId,
            moduleTitle: title,
          );
        },
      ),

      // DERS ÖĞRENME
      GoRoute(
        path: '/lesson-learn/:moduleId/:lessonId',
        builder: (context, state) {
          final moduleId = state.pathParameters['moduleId']!;
          final lessonId = state.pathParameters['lessonId']!;

          String title = state.uri.queryParameters['title'] ?? 'Lesson';
          final extra = state.extra;
          if (extra is Map && extra['title'] != null) {
            title = extra['title'].toString();
          }

          return LessonLearnPage(
            moduleId: moduleId,
            lessonId: lessonId,
            title: title,
          );
        },
      ),

      // DERS ÇEVİRİ / CÜMLE
      GoRoute(
        path: '/lesson-translate/:moduleId/:lessonId',
        builder: (context, state) {
          final moduleId = state.pathParameters['moduleId']!;
          final lessonId = state.pathParameters['lessonId']!;
          final title = state.uri.queryParameters['title'] ?? 'Lesson';
          return SentenceTranslatePage(
            moduleId: moduleId,
            lessonId: lessonId,
            title: title,
          );
        },
      ),

      // DERS QUIZ
      GoRoute(
        path: '/lesson-quiz/:moduleId/:lessonId',
        builder: (context, state) {
          final moduleId = state.pathParameters['moduleId']!;
          final lessonId = state.pathParameters['lessonId']!;
          final title = state.uri.queryParameters['title'] ?? 'Lesson Quiz';
          return LessonQuizPage(
            moduleId: moduleId,
            lessonId: lessonId,
            title: title,
          );
        },
      ),

      // RESULT
      GoRoute(
        path: '/result',
        builder: (context, state) {
          final correct = int.tryParse(state.uri.queryParameters['correct'] ?? '0') ?? 0;
          final total = int.tryParse(state.uri.queryParameters['total'] ?? '0') ?? 0;
          final earned = int.tryParse(state.uri.queryParameters['earned'] ?? '0') ?? 0;
          return ResultPage(
            correct: correct,
            total: total,
            earned: earned,
          );
        },
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}