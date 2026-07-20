import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  ScrollView,
  ActivityIndicator,
  Alert,
} from 'react-native';
import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';

const DictionaryScreen = () => {
  const [searchTerm, setSearchTerm] = useState('');
  const [definition, setDefinition] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const searchWord = async () => {
    if (!searchTerm.trim()) {
      Alert.alert('Error', 'Please enter a word to search');
      return;
    }

    setLoading(true);
    setError('');
    setDefinition(null);

    try {
      const response = await axios.get(
        `https://api.dictionaryapi.dev/api/v2/entries/en/${searchTerm.toLowerCase()}`
      );
      if (response.data && response.data.length > 0) {
        setDefinition(response.data[0]);
      }
    } catch (err) {
      setError('Word not found. Try another word.');
      console.error('Dictionary API Error:', err);
    } finally {
      setLoading(false);
    }
  };

  const saveDefinition = async () => {
    if (!definition) return;

    try {
      const savedDefinitions = await AsyncStorage.getItem('savedDefinitions');
      const existingDefinitions = savedDefinitions
        ? JSON.parse(savedDefinitions)
        : [];

      const newDefinition = {
        id: Date.now().toString(),
        word: definition.word,
        definition: definition.meanings[0]?.definitions[0]?.definition || '',
        partOfSpeech: definition.meanings[0]?.partOfSpeech || '',
        savedAt: new Date().toLocaleString(),
      };

      const updatedDefinitions = [...existingDefinitions, newDefinition];
      await AsyncStorage.setItem(
        'savedDefinitions',
        JSON.stringify(updatedDefinitions)
      );

      Alert.alert('Success', 'Definition saved!');
    } catch (error) {
      Alert.alert('Error', 'Failed to save definition');
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.searchContainer}>
        <TextInput
          style={styles.searchInput}
          placeholder="Search a word..."
          value={searchTerm}
          onChangeText={setSearchTerm}
          onSubmitEditing={searchWord}
        />
        <TouchableOpacity style={styles.searchButton} onPress={searchWord}>
          <Text style={styles.searchButtonText}>Search</Text>
        </TouchableOpacity>
      </View>

      {loading && <ActivityIndicator size="large" color="#2196F3" />}

      {error && <Text style={styles.errorText}>{error}</Text>}

      {definition && (
        <ScrollView style={styles.definitionContainer}>
          <Text style={styles.word}>{definition.word}</Text>

          {definition.phonetic && (
            <Text style={styles.phonetic}>{definition.phonetic}</Text>
          )}

          {definition.meanings && definition.meanings.length > 0 && (
            <View>
              {definition.meanings.map((meaning, index) => (
                <View key={index} style={styles.meaningSection}>
                  <Text style={styles.partOfSpeech}>
                    {meaning.partOfSpeech}
                  </Text>

                  {meaning.definitions && meaning.definitions.length > 0 && (
                    <View>
                      <Text style={styles.definitionLabel}>Definitions:</Text>
                      {meaning.definitions.map((def, idx) => (
                        <Text key={idx} style={styles.definition}>
                          • {def.definition}
                        </Text>
                      ))}
                    </View>
                  )}

                  {meaning.examples && meaning.examples.length > 0 && (
                    <View>
                      <Text style={styles.exampleLabel}>Examples:</Text>
                      {meaning.examples.map((example, idx) => (
                        <Text key={idx} style={styles.example}>
                          " {example} "
                        </Text>
                      ))}
                    </View>
                  )}
                </View>
              ))}
            </View>
          )}

          <TouchableOpacity
            style={styles.saveButton}
            onPress={saveDefinition}
          >
            <Text style={styles.saveButtonText}>Save Definition</Text>
          </TouchableOpacity>
        </ScrollView>
      )}

      {!definition && !loading && !error && (
        <Text style={styles.placeholderText}>
          Search for a word to see its definition
        </Text>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
    padding: 15,
  },
  searchContainer: {
    flexDirection: 'row',
    marginBottom: 20,
  },
  searchInput: {
    flex: 1,
    borderWidth: 1,
    borderColor: '#ddd',
    padding: 12,
    borderRadius: 8,
    marginRight: 10,
    fontSize: 16,
  },
  searchButton: {
    backgroundColor: '#2196F3',
    padding: 12,
    borderRadius: 8,
    justifyContent: 'center',
  },
  searchButtonText: {
    color: 'white',
    fontWeight: 'bold',
  },
  definitionContainer: {
    backgroundColor: 'white',
    borderRadius: 8,
    padding: 15,
    marginBottom: 20,
  },
  word: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 5,
  },
  phonetic: {
    fontSize: 14,
    color: '#2196F3',
    marginBottom: 15,
  },
  meaningSection: {
    marginBottom: 20,
    paddingBottom: 15,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  partOfSpeech: {
    fontSize: 16,
    fontStyle: 'italic',
    color: '#666',
    marginBottom: 10,
  },
  definitionLabel: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
  },
  definition: {
    fontSize: 14,
    color: '#555',
    marginBottom: 8,
    marginLeft: 10,
  },
  exampleLabel: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#333',
    marginTop: 10,
    marginBottom: 8,
  },
  example: {
    fontSize: 13,
    color: '#2196F3',
    marginBottom: 5,
    marginLeft: 10,
    fontStyle: 'italic',
  },
  saveButton: {
    backgroundColor: '#4CAF50',
    padding: 15,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 15,
  },
  saveButtonText: {
    color: 'white',
    fontWeight: 'bold',
    fontSize: 16,
  },
  errorText: {
    color: '#ff6b6b',
    fontSize: 16,
    textAlign: 'center',
    marginTop: 20,
  },
  placeholderText: {
    color: '#999',
    fontSize: 16,
    textAlign: 'center',
    marginTop: 50,
  },
});

export default DictionaryScreen;
