import { defineDiverRoute } from 'diver-expo-builder/route';
import { useLocalSearchParams } from 'expo-router';
import { Text, View } from 'react-native';

export const diverRoute = defineDiverRoute({
  name: 'Docs',
  description: 'Documentation pages addressed by a catch-all path',
});

// Catch-all segment: the builder emits this route as docs/:slug.
export default function Docs() {
  const { slug } = useLocalSearchParams<{ slug: string[] }>();

  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
      <Text>Docs: {[slug ?? []].flat().join(' / ')}</Text>
    </View>
  );
}
