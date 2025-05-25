# Makefile for Swift project formatting and linting

# Format all Swift files using SwiftFormat
format:
	@echo "🔧 Formatting Swift files with SwiftFormat..."
	@swiftformat . --quiet

# Lint all Swift files using SwiftLint
lint:
	@echo "🔍 Linting Swift files with SwiftLint..."
	@swiftlint

# Optional: Run both format and lint in one go
check: format lint
	@echo "✅ Format and lint complete."

.PHONY: format lint check setup

setup:
	@echo "Setting up RunAICoach..."
	@if [ ! -f RunAICoach/Info.plist.template ]; then \
		echo "Error: Info.plist.template not found. Please make sure you're in the project root directory."; \
		exit 1; \
	fi
	@if [ ! -f RunAICoach/Info.plist ]; then \
		echo "Creating Info.plist from template..."; \
		cp RunAICoach/Info.plist.template RunAICoach/Info.plist; \
	fi
	@if grep -q "YOUR_API_KEY_HERE" RunAICoach/Info.plist; then \
		echo "Please enter your OpenAI API key:"; \
		read -s api_key; \
		if [ -z "$$api_key" ]; then \
			echo "Error: API key cannot be empty"; \
			exit 1; \
		fi; \
		sed -i '' "s/YOUR_API_KEY_HERE/$$api_key/" RunAICoach/Info.plist; \
		echo "API key has been added to Info.plist"; \
	fi
	@echo "✅ Setup complete!"
	@echo "Note: Info.plist is gitignored but ready for local development."
