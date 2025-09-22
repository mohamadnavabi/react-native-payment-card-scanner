import React from 'react';

import {
  PermissionsAndroid,
  Platform,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import PaymentCardScanner, {
  ScanResult,
} from 'react-native-payment-card-scanner';

export default function App() {
  const [result, setResult] = React.useState<string | undefined>();

  React.useEffect(() => {
    const startScan = async () => {
      try {
        if (Platform.OS === 'android') {
          const granted = await PermissionsAndroid.request(
            PermissionsAndroid.PERMISSIONS.CAMERA
          );
          if (granted !== PermissionsAndroid.RESULTS.GRANTED) {
            console.log('Camera permission denied');
            return;
          }
        }

        PaymentCardScanner.scan(
          'اسکن کارت',
          'پشت بلوکارت فرد منتخب را مقابل دوربین قرار دهید',
          '',
          ''
        ).then((res: ScanResult) => {
          setResult(res.PAN);
        });
      } catch (e) {
        console.log(e);
      }
    };

    startScan();
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
