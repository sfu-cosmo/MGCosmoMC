import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import pylab as pil

mg = np.loadtxt('test_LCDM_mg_scalCls.dat')
gr = np.loadtxt('test_LCDM_std_scalCls.dat')

plt.semilogx(mg[:,0], (mg[:,1] - gr[:,1])/gr[:,1])

plt.show()
