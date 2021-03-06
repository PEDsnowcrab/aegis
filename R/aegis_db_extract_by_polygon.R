
aegis_db_extract_by_polygon = function( sppoly, spatial_domain="SSE", covfields=NULL, force_matrix=TRUE, redo=FALSE, ... ) {

    outputdirectory = getwd()
    fn = file.path( outputdirectory, paste( "aegis_db_extract_by_polygon", spatial_domain, "rdata", sep="." ) )
    message ( "\n Temporary file being made in the current work directory:  ", fn, "\n")

    out = NULL

    if (!redo) {
      if (file.exists(fn)) load(fn)
      if( !is.null(out) ) return(out)
    }

    # aggregate summaries of covariate fields by polygons
    pb = aegis.bathymetry::bathymetry_parameters( spatial_domain=spatial_domain )
    pts = bathymetry.db( p=pb, DS="baseline" )
    pts = SpatialPoints(pts, proj4string=sp::CRS(pb$aegis_proj4string_planar_km) )
    pts = spTransform( pts, sp::CRS(proj4string(sppoly)) )
    # match each datum to an area
    o = over( pts, sppoly)
    pts$AUID = as.character( o$AUID )
    pts$rowindex = 1:nrow(pts)

    o = NULL

    if (is.null(covfields)) covfields = aegis_db_extract(spatial_domain=spatial_domain, ... )

    fnsummary = function(i) {
      m = mean(covfields[[vn]][i], na.rm=TRUE )
      s = sd(covfields[[vn]][i], na.rm=TRUE )
      return( cbind(m,s))
    }

    fnsummary_mean = function(i) {
      ooo = NULL
      for( j in 1:ncol(covfields[[vn]])) {
        m = mean(covfields[[vn]][i,j], na.rm=TRUE )
        ooo = cbind(ooo,m)
      }
      return( ooo)
    }

    fnsummary_sd = function(i) {
      ooo = NULL
      for( j in 1:ncol(covfields[[vn]])) {
        s = sd(covfields[[vn]][i,j], na.rm=TRUE )
        ooo = cbind(ooo,s)
      }
      return( ooo)
    }

    means = list()
    sds = list()
    datatype = list()

    auid = as.character( sppoly$AUID )
    cvn = names(covfields)

    for ( vn in cvn ) {
      if (is.vector(covfields[[vn]])) {
         datatype[[vn]] = "vector"
         res  = aggregate( rowindex ~ AUID, pts@data, fnsummary, na.action=na.omit, drop=FALSE )
         mc = matrix(NA, nrow=length(auid), ncol=1, dimnames=list(auid, vn ) )
         mc[ match(res$AUID, auid), ] = res$rowindex[,1][]
         means[[vn]] = mc[]
         mc=NULL
         sc = matrix(NA, nrow=length(auid), ncol=1, dimnames=list(auid, vn ) )
         sc[ match(res$AUID, auid), ] = res$rowindex[,2][]
         sds[[vn]] = sc[]
         sc = NULL
      }

      if (is.matrix(covfields[[vn]])) {
        datatype[[vn]] = "matrix"
        m = aggregate( rowindex ~ AUID, pts@data, fnsummary_mean, na.action=na.omit, drop=FALSE )
        if (is.matrix(m$rowindex)) {
          mc = matrix( NA, nrow=length(auid), ncol=ncol(m$rowindex), dimnames=list( auid, dimnames(covfields[[vn]])[[2]] ) )
          mc[ match(m$AUID, auid), ] = m$rowindex[]
          means[[vn]] = mc[]
          mc = NULL
        } else {
          mc = matrix(NA, nrow=length(auid), ncol=1, dimnames=list(auid, vn ) )
          mc[ match(m$AUID, auid), ] = m$rowindex[,1][]
          means[[vn]] = mc[]
        }

        s = aggregate( rowindex ~ AUID, pts@data, fnsummary_sd, na.action=na.omit, drop=FALSE )
        if (is.matrix(s$rowindex)) {
          sc = matrix( NA, nrow=length(auid), ncol=ncol(s$rowindex), dimnames=list( auid, dimnames(covfields[[vn]])[[2]] ) )
          sc[ match(s$AUID, auid), ] = s$rowindex[]
          sds[[vn]] = sc[]
          sc = NULL
        } else {
          sc = matrix( NA, nrow=length(auid), ncol=1, dimnames=list( auid, vn ) )
          sc[ match(s$AUID, auid), ] = s$rowindex[,2][]
          sds[[vn]] = sc[]
          sc = NULL
        }
      }
    }

    if (force_matrix) {
      i = which( datatype == "matrix" )
      if (length(i) > 0) {
        j = which( datatype == "vector" )
        if (length(j) > 0 ) {
          matrix_dim = dim( means[[cvn[i[1]]]] )
          matrix_colnames = dimnames( means[[cvn[i[1]]]])[[2]]
          matrix_rownames = auid
          for (k in j){
            vn = cvn[k]
            vv = means[[vn]]
            nvv = length(vv)
            mm = matrix( vv, nrow=nvv, ncol=matrix_dim[2], dimnames=list( matrix_rownames, matrix_colnames ),  byrow=FALSE )
            ww = sds[[vn]]
            means[[vn]] = mm[]
            ss = matrix( ww, nrow=nvv, ncol=matrix_dim[2], dimnames=list( matrix_rownames, matrix_colnames ),  byrow=FALSE )
            sds[[vn]] = ss[]
            vn = vv = ww = mm = ss = NULL
          }
        }
      }
    }

    out = list(means=means, sds=sds)
    save(out, file=fn, compress=TRUE)
    return( out )

}
