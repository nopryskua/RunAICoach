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

.PHONY: format lint check
