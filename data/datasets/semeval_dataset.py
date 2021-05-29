import os
import pandas as pd
from torch.utils.data import Dataset
from sklearn import preprocessing
import torch

class SemevalDatset(Dataset):
    def __init__(self, csv_file):
        
        roberta = torch.hub.load('pytorch/fairseq', 'roberta.large')
        le = preprocessing.LabelEncoder()
        self.dataframe = pd.read_csv(csv_file)

        self.dataframe['explanation'] = le.fit_transform(self.dataframe.explanation.values)
        self.tokens = [roberta.encode(x, y) for x, y in zip(self.dataframe['chunk1'], self.dataframe['chunk2'])]


    def __len__(self):
        return len(self.dataframe)

    def __getitem__(self, idx):
        x_data = self.tokens 
        value_data = torch.Tensor(self.dataframe.iloc[:, 2].values)
        exp_data = torch.Tensor(self.dataframe.iloc[:, 3].values)
        
        return x_data[idx],value_data[idx],  exp_data[idx]