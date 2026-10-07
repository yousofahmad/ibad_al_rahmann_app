with open("lib/features/wird/ui/khatma_details_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re

target = r'''          return const SizedBox\.shrink\(\);
        \},
      \),
    \);
  \}
\}'''

replacement = r'''          return const SizedBox.shrink();
        },
      );
        },
      ),
    );
  }
}'''

content = re.sub(target, replacement, content)

with open("lib/features/wird/ui/khatma_details_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("done")
