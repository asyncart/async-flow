TEST_DIR_PATH=$(cd test && pwd)
ASYNC_ARTWORK_TEST_DIR=$(cd test/AsyncArtwork && pwd)
NFT_AUCTION_TEST_DIR=$(cd test/NFTAuction && pwd)
FINAL_PATH="$TEST_DIR_PATH:$ASYNC_ARTWORK_TEST_DIR:$NFT_AUCTION_TEST_DIR"
export PYTHONPATH=$FINAL_PATH