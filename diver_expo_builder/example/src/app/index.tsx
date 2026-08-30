import { Link } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';

// The root route resolves to a bare `/` with no host, so diver-expo-builder
// skips it — it cannot be expressed as `scheme://host/path`.
export default function Home() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>diver-expo-builder example</Text>
      <Link href="/profile" style={styles.link}>Profile</Link>
      <Link href="/settings?tab=general" style={styles.link}>Settings</Link>
      <Link href="/products" style={styles.link}>Products</Link>
      <Link href="/docs/getting-started/install" style={styles.link}>Docs</Link>
      <Link href="/about" style={styles.link}>About</Link>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 12 },
  title: { fontSize: 20, fontWeight: '600', marginBottom: 12 },
  link: { fontSize: 16, color: '#208AEF' },
});
