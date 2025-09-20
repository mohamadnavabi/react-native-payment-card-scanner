import React from 'react';

import { StyleSheet, Text, View } from 'react-native';
import PaymentCardScanner, {
  ScanResult,
} from 'react-native-payment-card-scanner';

export default function App() {
  const [result, setResult] = React.useState<string | undefined>();

  React.useEffect(() => {
    PaymentCardScanner.scan(
      'اسکن کارت',
      'پشت بلوکارت فرد منتخب را مقابل دوربین قرار دهید',
      'topTextFontFamilyName',
      'bottomTextFontFamilyName'
    ).then((res: ScanResult) => {
      setResult(res.PAN);
    });
  }, []);

  return (
    <View style={styles.container}>
      <Text>Result: {result}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});
