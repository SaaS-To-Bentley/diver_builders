import { Link } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';

// Plain-object form (no defineDiverRoute import) — still supported by the
// builder. The other routes use defineDiverRoute() for type-checked metadata.
export const diverRoute = {
  name: 'Products',
  description: 'Product overview list',
};

export default function Products() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Products</Text>
      <Link href="/products/42?ref=example" style={styles.link}>Product 42</Link>
      <Link href="/products/1337" style={styles.link}>Product 1337</Link>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 12 },
  title: { fontSize: 18, fontWeight: '600' },
  link: { fontSize: 16, color: '#208AEF' },
});
