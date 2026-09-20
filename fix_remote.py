with open("lib/services/remote_config_service.dart", "r", encoding="utf-8") as f:
    content = f.read()
import re
new_content = re.sub(r'class RemoteConfigService \{.*?(?=class RemoteConfigService \{)', '', content, flags=re.DOTALL)
with open("lib/services/remote_config_service.dart", "w", encoding="utf-8") as f:
    f.write(new_content)
print("Fixed remote_config_service.dart")
