# react-native-payment-card-scanner

Payment Card Scanner for React Native

## Installation

```sh
npm install react-native-payment-card-scanner
```

## Usage

```js
import PaymentCardScanner from "react-native-payment-card-scanner";

// ...

PaymentCardScanner.scan(
    "اسکن کارت",
    "کارت بلوبانک خود را درون کادر قرار دهید"
).then((result: any) => {
    console.log(result);
}).catch((error: any) => {});
```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT
