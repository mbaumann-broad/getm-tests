from setuptools import setup, find_packages

setup(
    name='inject_gcloud_credentials',
    version='0.0.1',
    description='miniwdl plugin to inject gcloud credentials. This is for local testing.',
    author='Brian Hannafious',
    py_modules=["inject_credentials"],
    python_requires='>=3.6',
    setup_requires=[],
    install_requires=[""],
    reentry_register=True,
    entry_points={
        'miniwdl.plugin.task': ['inject_credentials = inject_credentials:main'],
    }
)
