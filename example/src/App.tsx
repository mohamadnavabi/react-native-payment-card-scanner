import * as React from 'react';

import { StyleSheet, View, Text } from 'react-native';
import PaymentCardScanner from 'react-native-payment-card-scanner';

export default function App() {
  const [result, setResult] = React.useState<number | undefined>();

  React.useEffect(() => {
    PaymentCardScanner.scan(
    "اسکن کارت",
    "کارت بلوبانک خود را درون کادر قرار دهید"
    ).then((result: any) => {
      setResult(result.PAN);
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
