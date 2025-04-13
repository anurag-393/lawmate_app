import 'package:flutter/material.dart';
import 'package:lawmate_ai_app/core/constants/app_colors.dart';
import 'package:lawmate_ai_app/core/model/conversation.dart';
import 'package:lawmate_ai_app/screens/chat/chat_screen.dart';
import 'package:lawmate_ai_app/screens/highlisht/document_highlight_screeen.dart';
import 'package:lawmate_ai_app/screens/saved_item_screen.dart';
import 'package:lawmate_ai_app/screens/summary/summary_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.menu,
            color: AppColors.textColor,
          ),
          onPressed: () {},
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: AppColors.surfaceColor,
              child: IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => SavedItemsScreen(),
                    ),
                  );
                },
                icon: Icon(Icons.history),
                color: AppColors.textColor,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: AppColors.surfaceColor,
              child: Icon(
                Icons.person,
                color: AppColors.textColor,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hi, John Doe",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "How may I help you today?",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
              SizedBox(height: 24),
              _buildCustomGrid(context),
              SizedBox(height: 24),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "History",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textColor,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      "See all",
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              ListView(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _buildHistoryItem(
                    context,
                    color: Color(0xFF6B4EFF),
                    title:
                        "Tell me the major rights of employees",
                  ),
                  _buildHistoryItem(
                    context,
                    color: Color(0xFFFF6B8A),
                    title:
                        "Mark important parts of the document",
                  ),
                  _buildHistoryItem(
                    context,
                    color: Color(0xFFB476FF),
                    title:
                        "What is The Code of Wages 2019?",
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 266,
            child: _buildFeatureCard(
              context,
              color: Color(0xFF6B4EFF),
              icon: Icons.mic,
              title: "Chat with LawMate",
              destinationScreen: ChatScreen(),
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              SizedBox(
                height: 130,
                child: _buildFeatureCard(
                  context,
                  color: Color(0xFFFF6B8A),
                  icon: Icons.chat_bubble_outline,
                  title: "Analyze Document",
                  destinationScreen:
                      DocumentAnalysisScreen(),
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                height: 130,
                child: _buildFeatureCard(
                  context,
                  color: Color(0xFFB476FF),
                  icon: Icons.image,
                  title: "Summarize Document",
                  destinationScreen:
                      DocumentSummaryScreen(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required Widget
    destinationScreen, // New parameter for navigation
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => destinationScreen,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 10,
              left: 8,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 10,
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(
    BuildContext context, {
    required Color color,
    required String title,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: Icon(Icons.history, color: Colors.white),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.textColor,
                fontSize: 14,
              ),
            ),
          ),
          Icon(
            Icons.more_vert,
            color: AppColors.secondaryTextColor,
          ),
        ],
      ),
    );
  }
}
