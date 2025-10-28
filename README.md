# React Native Iranian Bank Card Scanner

A powerful React Native library for scanning Iranian bank cards (debit/credit cards) using OCR technology. This package is specifically designed for Iranian banking system and supports Persian/Farsi text display.

## Features

- ✅ **Iranian Bank Card Support**: Optimized for Iranian debit and credit cards
- ✅ **OCR Technology**: Advanced card number and expiry date detection
- ✅ **Persian/Farsi Support**: Full support for Persian text display
- ✅ **Cross-Platform**: Works on both Android and iOS
- ✅ **Easy Integration**: Simple API for React Native apps
- ✅ **Custom Fonts**: Support for custom Persian fonts
- ✅ **High Accuracy**: Optimized for Iranian card formats

## Supported Iranian Banks

This scanner works with cards from major Iranian banks including:

- Bank Melli Iran (بانک ملی ایران)
- Bank Tejarat (بانک تجارت)
- Bank Saderat (بانک صادرات)
- Bank Mellat (بانک ملت)
- Bank Parsian (بانک پارسیان)
- Bank Pasargad (بانک پاسارگاد)
- And other Iranian banks

## Installation

```sh
npm install react-native-payment-card-scanner
```

### iOS Setup

```sh
cd ios && pod install
```

### Android Setup

No additional setup required for Android.

## Usage

```js
import PaymentCardScanner from 'react-native-payment-card-scanner';

// Scan Iranian bank card
PaymentCardScanner.scan(
  'اسکن کارت بانکی', // Top text in Persian
  'کارت بانکی خود را مقابل دوربین قرار دهید', // Bottom text in Persian
  'Vazir', // Persian font family name
  'Vazir' // Persian font family name
)
  .then((result) => {
    console.log('Card Number:', result.PAN);
    console.log('Expiry Date:', result.EXP);
    console.log('CVV:', result.CVV);
  })
  .catch((error) => {
    console.error('Scan failed:', error);
  });
```

## API Reference

### `PaymentCardScanner.scan(topText, bottomText, topTextFontFamily, bottomTextFontFamily)`

Scans an Iranian bank card and returns the extracted information.

**Parameters:**

- `topText` (string): Text displayed at the top of the scanner (supports Persian)
- `bottomText` (string): Text displayed at the bottom of the scanner (supports Persian)
- `topTextFontFamily` (string): Font family for top text
- `bottomTextFontFamily` (string): Font family for bottom text

**Returns:** Promise that resolves to an object with:

- `PAN` (string): Card number
- `EXP` (string): Expiry date in MM/YY format
- `CVV` (string): CVV code (if detected)

## Example Result

```js
{
  PAN: "1234567890123456",
  EXP: "12/25",
  CVV: "123"
}
```

## Persian Font Support

The library supports Persian fonts. You can use fonts like:

- Vazir
- Samim
- Shabnam
- IRANSans
- And other Persian fonts

## Requirements

- React Native 0.60+
- Android API 21+
- iOS 10.0+

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

## Author

**Mohammad Navabi** - [mohammadnavabi.ir](https://mohammadnavabi.ir)

---

_This package is specifically designed for Iranian banking system and Persian language support._
