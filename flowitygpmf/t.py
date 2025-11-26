from typing import NamedTuple
from datetime import datetime, timedelta, timezone

TYPE_CONV = {
    "d": ("float64", "d"),
    "f": ("float32", "f"),
    "b": ("int8", "b"),
    "B": ("uint8", "B"),
    "s": ("int16", "h"),
    "S": ("uint16", "H"),
    "l": ("int32", "i"),
    "L": ("uint32", "I"),
    "j": ("int64", "q"),
    "J": ("uint64", "Q"),
}

class KLVLength(NamedTuple):
    """ A KLV Length

    Attributes
    ----------
    type: str
        The type of the value.
    size: int
        The size of the value.
    repeat: int
        The number of times the value is repeated.
    """
    type: str
    size: int
    repeat: int

class KLVItem(NamedTuple):
    """ A KLV Item

    Attributes
    ----------
    key: str
        The fourcc code of the item.
    length: KLVLength
        The length of the item.
    value: bytes
        The payload of the item.
    """
    key: str
    length: "KLVLength"
    value: bytes
    fourcc: bytes 



