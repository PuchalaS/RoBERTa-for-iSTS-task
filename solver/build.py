# encoding: utf-8

import torch


def make_optimizer(cfg, model):
    return torch.optim.Adam(model.parameters(), lr= cfg.SOLVER.BASE_LR)
