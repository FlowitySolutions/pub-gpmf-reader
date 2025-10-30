from pygpmf.t import KLVItem, KLVLength
import struct, logging


def ceil4(x):
    """ Find the closest greater or equal multiple of 4"""
    return (((x - 1) >> 2) + 1) << 2    

logger = logging.getLogger(__name__)

class UnexpectedEndOfStream(Exception):
    """Exception raised when the stream ends unexpectedly."""
    def __init__(self, message="Unexpected end of stream encountered."):
        self.message = message
        super().__init__(self.message)

class KLMReader():
    data:bytes

    def __init__(self, dbin) -> None:
        self.data = dbin

    @staticmethod
    def read_all(data:bytes, unfold_keys:bool=[], path_id:str="gpmf", parent_id=0):
      i = 0
      while KLMReader.has_next(data):
        i += 1
        klm, data = KLMReader.pop_klm(data)        
        if klm.key in unfold_keys:
            nest_id = f"{path_id}-{i}"
#            print(f"############ {nest_id}")
            yield from KLMReader.read_all(klm.value, unfold_keys=unfold_keys, path_id=nest_id, parent_id=parent_id+1)
        else:
#            print(f"    {path_id}::{klm.key} -- {klm.length}")
            yield path_id, klm

    @staticmethod
    def pop_klm(bin:bytes) -> tuple[KLVItem, bytes]:
      head, bin = struct.unpack(">cccccBH", bin[:8]), bin[8:]
      fourcc = (b"".join(head[:4])).decode()
      type_str, size, repeat = head[4:]
      type_str = type_str.decode() if type_str != b'\x00' else "NST"
      payload_size = ceil4(size * repeat)
      payload, bin = bin[:payload_size], bin[payload_size:]
      assert len(payload) == payload_size, "Payload size mismatch"
      return KLVItem(fourcc, KLVLength(type_str, size, repeat), payload[:payload_size], fourcc=head), bin

    @staticmethod
    def has_next(bin:bytes):
      return len(bin) > 8


