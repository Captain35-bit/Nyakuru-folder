import React, { useState, useEffect, useFocusEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  Alert,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

const SavedDefinitionsScreen = () => {
  const [savedDefinitions, setSavedDefinitions] = useState([]);

  useFocusEffect(
    React.useCallback(() => {
      loadSavedDefinitions();
    }, [])
  );

  const loadSavedDefinitions = async () => {
    try {
      const definitions = await AsyncStorage.getItem('savedDefinitions');
      if (definitions) {
        setSavedDefinitions(JSON.parse(definitions));
      }
    } catch (error) {
      console.error('Error loading saved definitions:', error);
    }
  };

  const deleteDefinition = (id) => {
    Alert.alert('Delete Definition', 'Are you sure?', [
      { text: 'Cancel' },
      {
        text: 'Delete',
        onPress: async () => {
          const updatedDefinitions = savedDefinitions.filter(
            (d) => d.id !== id
          );
          setSavedDefinitions(updatedDefinitions);
          await AsyncStorage.setItem(
            'savedDefinitions',
            JSON.stringify(updatedDefinitions)
          );
        },
      },
    ]);
  };

  const renderDefinitionItem = ({ item }) => (
    <View style={styles.definitionCard}>
      <View style={styles.cardHeader}>
        <Text style={styles.word}>{item.word}</Text>
        <TouchableOpacity onPress={() => deleteDefinition(item.id)}>
          <Text style={styles.deleteButton}>Delete</Text>
        </TouchableOpacity>
      </View>
      {item.partOfSpeech && (
        <Text style={styles.partOfSpeech}>{item.partOfSpeech}</Text>
      )}
      <Text style={styles.definition}>{item.definition}</Text>
      <Text style={styles.savedDate}>{item.savedAt}</Text>
    </View>
  );

  return (
    <View style={styles.container}>
      <FlatList
        data={savedDefinitions}
        keyExtractor={(item) => item.id}
        renderItem={renderDefinitionItem}
        ListEmptyComponent={
          <Text style={styles.emptyText}>
            No saved definitions yet. Search and save from the Dictionary tab!
          </Text>
        }
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
    padding: 10,
  },
  definitionCard: {
    backgroundColor: 'white',
    padding: 15,
    marginBottom: 10,
    borderRadius: 8,
    shadowColor: '#000',
    shadowOpacity: 0.1,
    shadowRadius: 3,
    elevation: 3,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  word: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  deleteButton: {
    color: '#ff6b6b',
    fontWeight: 'bold',
  },
  partOfSpeech: {
    fontSize: 12,
    color: '#2196F3',
    fontStyle: 'italic',
    marginBottom: 8,
  },
  definition: {
    fontSize: 14,
    color: '#555',
    marginBottom: 10,
    lineHeight: 20,
  },
  savedDate: {
    fontSize: 11,
    color: '#999',
  },
  emptyText: {
    textAlign: 'center',
    color: '#999',
    marginTop: 50,
    fontSize: 16,
  },
});

export default SavedDefinitionsScreen;
