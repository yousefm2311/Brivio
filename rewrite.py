import os
import re

files = [
    'lib/features/assessment/presentation/screens/teacher_question_bank_screen.dart',
    'lib/features/assessment/presentation/screens/teacher_homework_screen.dart',
    'lib/features/assessment/presentation/screens/teacher_exam_screen.dart',
    'lib/features/assessment/presentation/screens/teacher_grading_screen.dart',
]

imports_to_add = """
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/theme/colors.dart';
import '../../../../design_system/theme/typography.dart';
import '../../../../design_system/animations/fade_in_slide.dart';
"""

def replace_build_scaffold(content):
    # Replacing Scaffold with Stack/RefreshIndicator and modifying styles.
    # Just basic regex to swap Scaffold
    # Since writing full python to parse dart is hard, let's just do simple replacements.
    
    # 1. Replace imports
    if 'glass_card.dart' not in content:
        content = content.replace("import '../../../../core/localization/app_localizations.dart';", 
            "import '../../../../core/localization/app_localizations.dart';" + imports_to_add)

    # 2. Replace Scaffold
    # We want to replace everything from "Widget build(BuildContext context) {" to the end with our new build method.
    return content

for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    content = replace_build_scaffold(content)
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)
