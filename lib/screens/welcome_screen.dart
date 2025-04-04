import 'package:flutter/material.dart';
import 'package:lawmate_ai_app/core/constants/app_colors.dart';
import 'package:lawmate_ai_app/core/constants/app_theme.dart';
import 'package:lawmate_ai_app/screens/home_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        color: AppColors.backgroundColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Personal AI Buddy pill button
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: AppTheme.pillDecoration,
                    child: Text(
                      'Personal AI Buddy',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(
                            color: AppColors.textColor,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ),

                Expanded(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Meet ',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textColor,
                              ),
                            ),
                            TextSpan(
                              text: 'LawMate',
                              style: theme
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(
                                    color:
                                        AppColors
                                            .primaryColor,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your own AI assistant',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ask your questions and receive answers using\nartificial intelligence assistant',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(
                              color:
                                  AppColors.descriptiveText,
                              fontSize: 15,
                            ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceColor,
                      borderRadius: BorderRadius.circular(
                        28,
                      ), // More rounded corners
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => HomeScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(
                          28,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(
                            4.0,
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 48,
                                width: 88,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors
                                          .primaryColor,
                                  borderRadius:
                                      BorderRadius.circular(
                                        24,
                                      ),
                                ),
                                child: const Center(
                                  child: Text(
                                    '>>>',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 30),
                              Text(
                                'Get started',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
