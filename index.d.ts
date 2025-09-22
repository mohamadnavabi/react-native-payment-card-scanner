declare module 'react-native-payment-card-scanner' {
  export interface ScanResult {
    PAN: string;
    CVV2?: string;
    EXP: string;
    IBAN: string;
  }

  export async function scan(
    topText: string,
    bottomText: string,
    topTextFont: string,
    bottomTextFont: string
  ): Promise<ScanResult>;

  export const PaymentCardScanner = {
    scan,
  };

  export default PaymentCardScanner;
}
