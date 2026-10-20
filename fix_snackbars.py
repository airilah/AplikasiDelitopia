import os
import re

def main():
    lib_path = r'c:\DELITOPIA\Aplikasi\delitopia_app-main\lib'
    
    # Fix commas left behind
    # Examples of bad syntax:
    # Helpers.showSnackbar(context, 
    #       'msg',
    #    , backgroundColor: Colors.green);
    # Helpers.showSnackbar(context, 'msg',);
    
    pattern1 = re.compile(r',\s*,\s*backgroundColor:')
    pattern2 = re.compile(r',\s*\)')
    pattern3 = re.compile(r'Helpers\.showSnackbar\(context,\s*\'(.*?)\',\s*backgroundColor:')
    
    for root, _, files in os.walk(lib_path):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                old_content = content
                content = re.sub(r',\s*,\s*backgroundColor:', r', backgroundColor:', content)
                content = re.sub(r',\s*\);', r');', content)
                
                # specific fix for add_phone_number_view.dart where we have trailing comma before backgroundColor
                # e.g., 'Verification code sent via ...', \n , backgroundColor: Colors.green);
                content = re.sub(r'\',\s*\n\s*,\s*backgroundColor:', r"',\n backgroundColor:", content)
                content = re.sub(r'\'\s*\n\s*,\s*backgroundColor:', r"'\n, backgroundColor:", content)
                content = re.sub(r'\)\s*,\s*backgroundColor:', r"), backgroundColor:", content)
                
                if old_content != content:
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print(f"Fixed syntax in {file}")

if __name__ == '__main__':
    main()
