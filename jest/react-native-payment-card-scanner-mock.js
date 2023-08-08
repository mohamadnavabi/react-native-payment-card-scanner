/**
 * @format
 */
/* eslint-disable no-undef */
  
const scanResult = {
    PAN: "unknown",
    CVV2: "unknown",
    EXP: "unknown",
    IBAN: "unknown",
}

const RNPaymentCardScannerMock = {
    scan: jest.fn(),
}

RNPaymentCardScannerMock.scan.mockResolvedValue(scanResult);

module.exports = RNPaymentCardScannerMock;