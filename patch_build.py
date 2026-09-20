import re

with open("lib/features/wird/ui/khatma_details_view.dart", "r", encoding="utf-8") as f:
    content = f.read()

target_build = """    return Scaffold(
      backgroundColor: effectivePaperColor,
      body: SizedBox(
        width: 1080.0, // Force high-res width like ShareCard
        height: 1920.0, // Force high-res height
        child: PageView.builder("""

replacement_build = """    return Scaffold(
      backgroundColor: effectivePaperColor,
      body: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 1080.0, // Force high-res width like ShareCard
            height: 1920.0, // Force high-res height
            child: PageView.builder("""

if target_build in content:
    content = content.replace(target_build, replacement_build)
    # now replace the closing parentheses of SizedBox
    
    target_build_end = """          },
        ),
      ),
    );
  }"""
    replacement_build_end = """          },
        ),
      ),
        ),
      ),
    );
  }"""
    content = content.replace(target_build_end, replacement_build_end)
    
    with open("lib/features/wird/ui/khatma_details_view.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Build method updated")
else:
    print("Target build not found")
