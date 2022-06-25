module.exports = async (promise) => {
  try {
    await promise;
    assert.fail("revert가 일어나야 했는데 일어나지 않았다;");
  } catch (e) {
    const revertFound = e.message.search("revert") >= 0; // revert 인덱스 찾아서 0보다 크면 true
    assert(revertFound, `Expected "revert", got ${e} instead`);
  }
};
