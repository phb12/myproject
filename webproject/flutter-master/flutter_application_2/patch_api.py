import os

file_path = 'lib/api.py'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
in_get_user_profile = False
inserted_count_logic = False

for line in lines:
    if 'def get_user_profile():' in line:
        in_get_user_profile = True
    
    if in_get_user_profile and 'if row:' in line and not inserted_count_logic:
        new_lines.append(line)
        new_lines.append("        # 🚨 查詢好友數量\n")
        new_lines.append("        cursor.execute('SELECT COUNT(*) FROM friends WHERE user1=? OR user2=?', (target_username, target_username))\n")
        new_lines.append("        friend_count = cursor.fetchone()[0]\n")
        inserted_count_logic = True
        continue

    if in_get_user_profile and "'weight': row[5] or 0," in line:
        new_lines.append(line)
        new_lines.append("            'friend_count': friend_count,\n")
        in_get_user_profile = False # Done patching this function
        continue

    new_lines.append(line)

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Successfully patched api.py")
