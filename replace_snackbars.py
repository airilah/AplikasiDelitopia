import os
import re

def main():
    lib_path = r'c:\DELITOPIA\Aplikasi\delitopia_app-main\lib'
    
    # We will search for ScaffoldMessenger.of(context).showSnackBar
    # and replace with Helpers.showSnackbar(context, ...)
    
    pattern1 = re.compile(
        r'ScaffoldMessenger\.of\((.*?)\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\((.*?)\)\s*,?\s*\)\s*,?\s*\);',
        re.DOTALL
    )
    
    pattern2 = re.compile(
        r'ScaffoldMessenger\.of\((.*?)\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\((.*?)\)\s*,\s*backgroundColor:\s*(.*?)\s*,?\s*\)\s*,?\s*\);',
        re.DOTALL
    )

    for root, _, files in os.walk(lib_path):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                original_content = content
                
                # Replace pattern 2 first
                content, count2 = pattern2.subn(r'Helpers.showSnackbar(\1, \2, backgroundColor: \3);', content)
                
                # Replace pattern 1
                content, count1 = pattern1.subn(r'Helpers.showSnackbar(\1, \2);', content)
                
                if count1 > 0 or count2 > 0:
                    # add import if not present
                    if 'Helpers.showSnackbar' in content and 'import' in content:
                        if 'helpers.dart' not in content:
                            # find last import
                            import_idx = content.rfind('import ')
                            end_of_line = content.find('\n', import_idx)
                            # calculate relative path or use package
                            import_stmt = "\nimport 'package:delitopia_v2/src/core/utils/helpers.dart';"
                            content = content[:end_of_line] + import_stmt + content[end_of_line:]
                            
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print(f"Updated {file}: {count1 + count2} replacements")

if __name__ == '__main__':
    main()
