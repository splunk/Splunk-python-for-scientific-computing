import exec_anaconda

exec_anaconda.exec_anaconda()

import sys
import os


def test_numpy():
    import numpy as np

    print(np.__version__)
    a = np.array([1, 2, 3, 4])
    m = a.mean()


def test_scipy():
    import scipy.stats

    a = scipy.stats.norm.rvs(size=10)


def test_sklearn():
    import numpy as np
    from sklearn.linear_model import LinearRegression
    from sklearn.tree import DecisionTreeRegressor

    X = np.array([[1, 5], [2, 4], [3, 2]])
    y = np.array([5, 7, 10])
    m = LinearRegression()
    m.fit(X, y)
    p = m.predict(X)

    print(X)
    print(y)
    print(p)

    return m


def test_tree():
    import numpy as np
    from sklearn.tree import DecisionTreeRegressor

    X = np.array([[1, 5], [2, 4], [3, 2]])
    y = np.array([5, 7, 10])
    m = DecisionTreeRegressor()
    m.fit(X, y)
    p = m.predict(X)

    print(X)
    print(y)
    print(p)


def test_pickle():
    import cPickle as pickle

    m = test_sklearn()
    p = pickle.dumps(m)
    r = pickle.loads(p)


if __name__ == "__main__":
    import nose

    nose.runmodule()
