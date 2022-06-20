import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-payment-card-scanner' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo managed workflow\n';

const PaymentCardScanner = NativeModules.PaymentCardScanner
  ? NativeModules.PaymentCardScanner
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export function scan(topText: string, bottomText: string, topTextFont: string, bottomTextFont: string): Promise<number> {
  return PaymentCardScanner.scan(topText, bottomText, topTextFont, bottomTextFont);
}

export default PaymentCardScanner;