import { Link, Stack } from 'expo-router';
import { Text, View } from 'react-native';

// `+` special files are not navigable routes; the builder skips this file.
export default function NotFound() {
  return (
    <>
      <Stack.Screen options={{ title: 'Not found' }} />
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', gap: 12 }}>
        <Text>This screen does not exist.</Text>
        <Link href="/" style={{ color: '#208AEF' }}>Go home</Link>
      </View>
    </>
  );
}
