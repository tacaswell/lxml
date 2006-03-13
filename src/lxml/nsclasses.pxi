# module-level API for namespace implementations

class NamespaceRegistryError(LxmlError):
    pass

class ElementBase(_Element):
    """All classes in namespace implementations must inherit from this
    one.  Note that subclasses *must not* override __init__ or __new__
    as there is absolutely undefined when these objects will be
    created or destroyed.  All state must be kept in the underlying
    XML."""
    pass

class XSLTElement(object):
    "NOT IMPLEMENTED YET!"
    pass

cdef object __NAMESPACE_CLASSES
__NAMESPACE_CLASSES = {}

def Namespace(ns_uri):
    if ns_uri:
        ns_utf = _utf8(ns_uri)
    else:
        ns_utf = None
    try:
        return __NAMESPACE_CLASSES[ns_utf]
    except KeyError:
        registry = __NAMESPACE_CLASSES[ns_utf] = _NamespaceRegistry(ns_uri)
        return registry

cdef class _NamespaceRegistry:
    "Dictionary-like registry for namespace implementations"
    cdef object _ns_uri
    cdef object _classes
    cdef object _extensions
    cdef object _xslt_elements
    def __init__(self, ns_uri):
        self._ns_uri = ns_uri
        self._classes = {}
        self._extensions = {}
        self._xslt_elements = {}

    def update(self, class_dict_iterable):
        """Forgivingly update the registry. If registered values are
        neither subclasses of ElementBase nor callable extension
        functions, or if their name starts with '_', they will be
        silently discarded. This allows registrations at the module or
        class level using vars(), globals() etc."""
        if hasattr(class_dict_iterable, 'iteritems'):
            class_dict_iterable = class_dict_iterable.iteritems()
        elif hasattr(class_dict_iterable, 'items'):
            class_dict_iterable = class_dict_iterable.items()
        for name, item in class_dict_iterable:
            if (name is None or name[:1] != '_') and callable(item):
                self[name] = item

    def __setitem__(self, name, item):
        if python.PyType_Check(item) and issubclass(item, ElementBase):
            d = self._classes
        elif name is None:
            raise NamespaceRegistryError, "Registered name can only be None for elements."
        elif python.PyType_Check(item) and issubclass(item, XSLTElement):
            d = self._xslt_elements
        elif callable(item):
            d = self._extensions
        else:
            raise NamespaceRegistryError, "Registered item must be callable."

        if name is None:
            name_utf = None
        else:
            name_utf = _utf8(name)
        d[name_utf] = item

    def __getitem__(self, name):
        name_utf = _utf8(name)
        return self._get(name_utf)

    cdef object _get(self, object name):
        cdef python.PyObject* dict_result
        dict_result = python.PyDict_GetItem(self._classes, name)
        if dict_result is NULL:
            dict_result = python.PyDict_GetItem(self._extensions, name)
        if dict_result is NULL:
            raise KeyError, "Name not registered."
        return <object>dict_result

    def clear(self):
        self._classes.clear()
        self._extensions.clear()
        #self.self._xslt_elements.clear()

cdef object _find_element_class(char* c_namespace_utf,
                                char* c_element_name_utf):
    cdef python.PyObject* dict_result
    cdef _NamespaceRegistry registry
    if c_namespace_utf is not NULL:
        dict_result = python.PyDict_GetItemString(
            __NAMESPACE_CLASSES, c_namespace_utf)
    else:
        dict_result = python.PyDict_GetItem(
            __NAMESPACE_CLASSES, None)
    if dict_result is NULL:
        return _Element

    registry = <_NamespaceRegistry>dict_result
    classes = registry._classes

    if c_element_name_utf is not NULL:
        dict_result = python.PyDict_GetItemString(
            classes, c_element_name_utf)
    else:
        dict_result = NULL

    if dict_result is NULL:
        dict_result = python.PyDict_GetItem(classes, None)

    if dict_result is not NULL:
        return <object>dict_result
    else:
        return _Element
