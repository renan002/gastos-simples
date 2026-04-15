# Gastos Simples

A fully local iOS expense tracker that reads payment screenshots from your photo library using on-device OCR and AI, so no data ever leaves your device.

## Features

- **Screenshot scanning** — pick any payment confirmation or bank notification from your gallery; the app crops, OCRs, and parses it automatically
- **On-device AI parsing** — uses Apple's Foundation Models framework (Apple Intelligence) to extract merchant name and amount; falls back to regex when unavailable
- **Notification timestamp detection** — reads the iOS notification timestamp in the top-right corner of screenshots to determine the transaction date
- **Category breakdown** — donut chart and per-category totals on the dashboard, filterable by month
- **Installment tracking** — records whether a purchase was paid in full (à vista) or in installments (parcelado), with current/total installment tracking
- **No backend, no cloud, no account** — SwiftData persistence, everything stays on device

## Requirements

- iOS 26+
- Xcode 16+
- Apple Intelligence enabled for AI-powered parsing (falls back to regex otherwise)
- Physical iPhone for photo library access (simulator cannot access real screenshots)

## Building

The `.xcodeproj` is generated from `project.yml` via [xcodegen](https://github.com/yonaskolb/XcodeGen).

```bash
# Install xcodegen if needed
brew install xcodegen

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open GastosSimples.xcodeproj
```

## How it works

1. Tap **+** and pick a screenshot from your gallery
2. Drag corner handles to crop the relevant area (or use the full image)
3. The app runs Vision OCR, then sends the extracted text to the on-device language model
4. Review and correct the pre-filled merchant name, amount, and date
5. Assign a category and set installment details
6. Data is saved locally with SwiftData

## Tech stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Persistence | SwiftData |
| OCR | Vision framework (`VNRecognizeTextRequest`) |
| AI parsing | Foundation Models (`LanguageModelSession`) |
| Charts | Swift Charts |
| Photo access | PhotosUI |

## License

Copyright (c) 2026 Renan Mastropaolo. All rights reserved.
