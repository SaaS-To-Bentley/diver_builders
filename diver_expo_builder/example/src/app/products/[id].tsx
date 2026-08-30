import { defineDiverRoute } from 'diver-expo-builder/route';
import { useLocalSearchParams } from 'expo-router';
import { Text, View } from 'react-native';

export const diverRoute = defineDiverRoute({
  name: 'Product details',
  description: 'Details for a single product',
});

// `id` matches the [id] path segment, so the builder emits it as part of the
// path (products/:id) and only `ref` ends up in the query list.
export default function ProductDetails() {
  const { id, ref } = useLocalSearchParams<{ id: string; ref?: string }>();

  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', gap: 8 }}>
      <Text>Product #{id}</Text>
      <Text>ref: {ref ?? '-'}</Text>
    </View>
  );
}
